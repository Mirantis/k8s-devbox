#!/bin/bash
. test/remote/common.sh

sudo apt-get install -y golang-go
sudo bash -c "CGO_ENABLED=0 go install -a -installsuffix cgo std"
mkdir -p $HOME/go

./install.sh home -nogo https://github.com/kubernetes/kubernetes.git
devbox-test-e2e-simple
