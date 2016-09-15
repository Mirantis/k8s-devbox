#!/bin/bash
set -u -e -x
cd "$(dirname "${BASH_SOURCE[0]}")"
trap "vagrant destroy" EXIT
vagrant up
tar -C .. -c . | vagrant ssh -- '
mkdir -p k8s-devbox &&
cd k8s-devbox &&
tar -xv &&
./install.sh home https://github.com/kubernetes/kubernetes.git
'
vagrant ssh -- /home/vagrant/k8s-devbox/test/e2e_simple.sh
