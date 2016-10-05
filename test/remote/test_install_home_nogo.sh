#!/bin/bash
. test/remote/common.sh

export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get update
sudo -E apt-get install -y golang-go
sudo bash -c "CGO_ENABLED=0 go install -a -installsuffix cgo std"
mkdir -p $HOME/go
export GOPATH=$HOME/go
export PATH=$HOME/go/bin:$PATH

./install.sh home -nogo https://github.com/kubernetes/kubernetes.git
devbox-test-e2e-simple
