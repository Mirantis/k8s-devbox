#!/usr/bin/env bash
preempt="--preemptible"
devbox_dir="$(dirname "${BASH_SOURCE[0]}")/.."
zone="${DEVBOX_GCE_ZONE:-us-central1-b}"
project="${DEVBOX_GCE_PROJECT:-$(gcloud config list --format 'value(core.project)' 2>/dev/null)}"
image_family="${DEVBOX_GCE_IMAGE:-ubuntu-1604-lts}"
image_project="${DEVBOX_GCE_IMAGE_PROJECT:-ubuntu-os-cloud}"
setup_machine_type="${DEVBOX_GCE_MACHINE_TYPE:-n1-standard-1}"
machine_type="${DEVBOX_GCE_MACHINE_TYPE:-n1-standard-4}"
projzone=(--project "${project}" --zone "${zone}")
projzones=(--project "${project}" --zones "${zone}")
tmp_instance="${DEVBOX_GCE_TMP_INSTANCE_NAME:-devbox-test-tmp}"
test_image_name="${DEVBOX_GCE_TEST_IMAGE_NAME:-devbox-test-image}"
# disk_type="${DEVBOX_GCE_DISK_TYPE:-pd-ssd}"
# disk_size="${DEVBOX_GCE_DISK_SIZE:-20GB}"

function devbox::gce::cleanup-test-instances () {
    local -a instances
    mapfile -t instances < <(gcloud compute instances list \
                                    --regexp='^devbox-test.*' \
                                    --format='value(name)' \
                                    "${projzones[@]}")
    if [ ${#instances[@]} -ne 0 ]; then
        gcloud compute instances delete "${instances[@]}" -q "${projzone[@]}"
    fi
}

function devbox::gce::cleanup-test-stuff () {
    devbox::gce::cleanup-test-instances
    local image_name="$(gcloud compute images list \
                               --regexp='^devbox-test.*' \
                               --format='value(name)' \
                               --project "${project}" \
                               --no-standard-images)"
    if [[ "$image_name" ]]; then
        gcloud compute images delete "$image_name" -q --project "${project}"
    fi

    local disk_name="$(gcloud compute disks list \
                              --regexp='^devbox-test.*' \
                              --format='value(name)' \
                              "${projzones[@]}")"
    if [[ "$disk_name" ]]; then
        gcloud compute disks delete "$disk_name" -q "${projzone[@]}"
    fi
}

function devbox::gce::ssh () {
    local host="$1"
    local cmd="$2"
    gcloud compute ssh \
           --ssh-flag="-o LogLevel=quiet" --ssh-flag="-o ConnectTimeout=30" \
           "${projzone[@]}" "${host}" --command \
           "$cmd"
}

function devbox::gce::wait-for-ssh () {
    local host="$1"
    for n in {1..5}; do
        if devbox::gce::ssh "${host}" true 2>/dev/null; then
            break
        fi
        sleep 5
    done
}

function devbox::gce::make-bare-instance () {
    local name="$1"
    local mtype="${2:-${machine_type}}"
    gcloud compute instances create "${name}" \
           --image-project "${image_project}" \
           --image-family "${image_family}" \
           --machine-type "${mtype}" \
           "${projzone[@]}"
    devbox::gce::wait-for-ssh "${name}"
}

function devbox::gce::make-provisioned-image () {
    local image_name="$1"
    local provision_script="$2"
    devbox::gce::make-bare-instance "${tmp_instance}" "${setup_machine_type}"
    devbox::gce::ssh "${tmp_instance}" "sudo bash -s" <"$provision_script"
    gcloud compute instances delete -q "${tmp_instance}" --keep-disks boot "${projzone[@]}"
    gcloud compute images create "${image_name}" \
           --source-disk "${tmp_instance}" \
           --source-disk-zone "${zone}" \
           --project "${project}"
    gcloud compute disks delete -q "${tmp_instance}" "${projzone[@]}"
}

function devbox::gce::make-test-instance () {
    local name="$1"
    gcloud compute instances create "${name}" \
           $preempt \
           --image "${test_image_name}" \
           --machine-type "${machine_type}" \
           "${projzone[@]}"
           # --boot-disk-type "${disk_type}" \
           # --boot-disk-size "${disk_size}" \
    devbox::gce::wait-for-ssh "${name}"
}

function devbox::gce::delete-instance () {
    local name="$1"
    gcloud compute instances delete "${name}" -q "${projzone[@]}"
}

function devbox::gce::copy-devbox () {
    local host="$1"
    tar -C "${devbox_dir}" -c --exclude .vagrant --exclude .git . |
        devbox::gce::ssh ${host} 'rm -rf k8s-devbox && mkdir k8s-devbox && tar -C k8s-devbox -x'
}
