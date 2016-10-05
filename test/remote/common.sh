#!/bin/bash
set -u -e

devbox_dir="$(pwd)"

# FIXME: rm/comment K8S_DIND_REPO_URL/BRANCH when optimize-docker-images is merged
dind_override='export K8S_DIND_REPO_URL="https://github.com/ivan4th/kubernetes-dind-cluster"; export K8S_DIND_BRANCH=optimize-docker-images; export DIND_PREPULL_BASE=ivan4th/kubernetes-dind-base:v1'
eval "$dind_override"
echo "$dind_override" >>~/.profile

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
