#!/bin/bash
set -u -e

devbox_dir="$(pwd)"

function devbox-test-e2e-simple () {
    local extra_cmds="${1:-true}"
    echo "${extra_cmds}" >/tmp/extra_cmds
    # "sudo su" is needed for "relogin" because in some tests
    # the user was just added to 'docker' group
    sudo su - "${USER}" -c "bash -lis" <<EOF
cdk
dind-up 8
list_e2e DNS | grep "should provide DNS for the cluster"
e2e "existing RC"
dind-down
EOF
}
