#!/bin/bash
set -u -e

# workaround for https://github.com/ansible/ansible-modules-core/issues/3706
# (fixed in Ansible 2.1.1).
# joshualund.golang role fails without this
export LANG=C
export LC_ALL=C
unset LANGUAGE

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
k8s_repo_url=
ansible_via_docker=
target_hostname=
provider_args=
vm_type=libvirt
USE_VIRTUALBOX="${USE_VIRTUALBOX:-}"
export ANSIBLE_ROLES_PATH=$script_dir/provisioning/roles

if [ $# -gt 0 ]; then
    if [ "$1" = "-d" ]; then
        ansible_via_docker=y
        shift
    fi
fi

if [ $# -eq 0 ]; then
    usage
fi

cmd="$1"
shift

if [ "$cmd" = "remote" ]; then
    if [ $# -eq 0 ]; then
        echo "must specify target hostname" 1>& 2
    fi
    target_hostname="$1"
    shift
fi

k8s_repo_url=
if [ $# -gt 0 ]; then
    k8s_repo_url="$1"
fi

if [[ "$OSTYPE" == darwin* && "$cmd" != "remote" ]]; then
    export USE_VIRTUALBOX=1
else
    export VAGRANT_DEFAULT_PROVIDER=libvirt
    provider_args="--provider=libvirt"
fi

if [ -n "$USE_VIRTUALBOX" ]; then
    vm_type=virtualbox
fi

function install_roles {
    mkdir -p $ANSIBLE_ROLES_PATH
    ansible-galaxy install -r requirements.yml
}

function usage {
    echo "usage:" 1>&2
    echo "  $0 vagrant [K8S_REPO_URL]"
    echo "  $0 host"
    echo "  $0 local [K8S_REPO_URL]"
    echo "  $0 remote HOST [K8S_REPO_URL]"
    exit 1
}

function install_using_vagrant {
    # https://kushaldas.in/posts/storage-volume-error-in-libvirt-with-vagrant.html
    # FIXME: happens too often for me for some reason
    virsh pool-refresh tmp >& /dev/null || true
    K8S_REPO_URL=$k8s_repo_url vagrant up $provider_args
}

function provision_vm_host {
    ansible-playbook -i localhost, -c local --ask-sudo-pass \
                     -e "devbox_type=vm_host vm_type=$vm_type" provisioning/playbook.yml
}

function install_via_ansible {
    conn_opts="$*"
    install_roles
    extra_vars="devbox_type=host vm_type=$vm_type"
    if [ -n "$k8s_repo_url" ]; then
        extra_vars="$extra_vars k8s_repo_url=$k8s_repo_url"
    fi
    ansible-playbook $conn_opts --ask-sudo-pass \
                     -e "$extra_vars" provisioning/playbook.yml
}

function install_locally {
    install_via_ansible -i localhost, -c local
}

function install_remotely {
    install_via_ansible -i "$target_hostname", --ssh-extra-args="-oForwardAgent=yes"
}

if ! hash ansible-playbook 2>&1; then
    ansible_via_docker=y
fi

if [ -n "$ansible_via_docker" ]; then
    echo "WiP: ansible invocation via docker doesn't work currently for vagrant due to ssh & file perm problems" 1>& 2
    exit 1
    # export PATH="$script_dir/ansible-via-docker:$PATH"
fi

case "$cmd" in
    vagrant)
        install_using_vagrant
        ;;
    host)
        provision_vm_host
        ;;
    local)
        install_locally
        ;;
    remote)
        install_remotely
        ;;
    *)
        usage
        ;;
esac
