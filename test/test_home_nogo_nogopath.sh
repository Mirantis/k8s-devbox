#!/bin/bash
set -u -e -x
cd "$(dirname "${BASH_SOURCE[0]}")"
trap "vagrant destroy" EXIT
vagrant up
tar -C .. -c . | vagrant ssh -- '
sudo apt-get install -y golang-go &&
sudo bash -c "CGO_ENABLED=0 go install -a -installsuffix cgo std" &&
mkdir -p k8s-devbox &&
cd k8s-devbox &&
tar -xv &&
./install.sh home -nogo https://github.com/kubernetes/kubernetes.git
'
vagrant ssh -- /home/vagrant/k8s-devbox/test/e2e_simple.sh
