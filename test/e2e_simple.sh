#!/bin/bash
set -e
# set -u should not be used for devbox shortcuts
K8S_DEVBOX_HOMEDIR_INSTALL=true . /home/vagrant/.k8s-devbox/k8s-devenv.sh
cdk
dind-up
list_e2e DNS | grep "should provide DNS for the cluster"
e2e "existing RC"
dind-down
