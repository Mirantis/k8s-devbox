#!/usr/bin/env bash
set -u -e -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ../scripts/gce.sh

debug=
while getopts "d" opt; do
    case $opt in
        d)
            debug=y
            ;;
        \?)
            echo "Usage: $0 [-d] [test_script_names.sh_separated_by_spaces...]" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

devbox::gce::cleanup-test-instances
if [[ ! "$debug" ]]; then
    trap devbox::gce::cleanup-test-instances EXIT
fi

# TBD: run local tests (./install.sh remote) -- local/ dir
i=0
if [ "$#" -eq 0 ]; then
    test_cases=($(cd remote && ls test_*.sh))
else
    test_cases=("$@")
fi
status=0
test_pids=()
for name in "${test_cases[@]}"; do
    if [ ! -f "remote/${name}" ]; then
        status=1
        echo "Invalid test name: ${name}" >&2
        continue
    fi
    (
        echo "************* ${name} START"
        instance_name="devbox-tester-${i}"
        while true; do
            if [[ "${name}" =~ _bare\.sh$ ]]; then
                devbox::gce::make-bare-instance "${instance_name}"
            else
                devbox::gce::make-test-instance "${instance_name}"
            fi
            devbox::gce::copy-devbox "${instance_name}"
            if devbox::gce::ssh "${instance_name}" "cd k8s-devbox && test/remote/$name" >&"remote-${name}".log; then
                echo "************* ${name} OK"
                devbox::gce::delete-instance "${instance_name}"
                break
            elif [[ $? -ne 255 ]]; then
                status=1
                echo "************* ${name} FAIL"
                if [[ ! "$debug" ]]; then
                    devbox::gce::delete-instance "${instance_name}"
                else
                    echo "************* Kept instance for ${name}: ${instance_name}"
                fi
                break
            fi
            echo "*** $name RETRY (possible instance preemption)"
            devbox::gce::delete-instance "${instance_name}"
            sleep 20
        done
    ) &
    test_pids[$((i++))]=$!
done

if [ ${#test_pids[@]} -gt 0 ]; then
    for pid in ${test_pids[*]}; do
        wait ${pid}
    done
fi

exit ${status}
