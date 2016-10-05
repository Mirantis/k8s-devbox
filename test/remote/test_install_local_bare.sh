#!/bin/bash
. test/remote/common.sh

echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu xenial main" | sudo tee /etc/apt/sources.list.d/ansible.list
echo "deb-src http://ppa.launchpad.net/ansible/ansible/ubuntu xenial main" | sudo tee -a /etc/apt/sources.list.d/ansible.list
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7BB9C367
DEBIAN_FRONTEND=noninteractive sudo -E apt-get update
sudo apt-get install -y ansible
sudo apt-get install -y sshpass openssh-client

./install.sh local https://github.com/kubernetes/kubernetes.git
devbox-test-e2e-simple
