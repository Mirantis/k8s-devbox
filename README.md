# Kubernetes Development Environment

k8s-devbox provides a reproducible development environment
for working on Kubernetes project.

It's currently tested on Ubuntu Xenial (x86_64) and Mac OS X 10.11.

For easy creation of local k8s clusters k8s-devbox uses
[kubernetes-dind-cluster](https://github.com/sttts/kubernetes-dind-cluster) tool
written by Dr. Stefan Schimanski.

Demo - Mac OS X, installation using `home` method, DIND cluster:
[![asciicast](https://asciinema.org/a/85690.png)](https://asciinema.org/a/85690)

Demo - Linux, installation using `vagrant` method, local and DIND clusters,
conformance tests:
[![asciicast](https://asciinema.org/a/cjemrekkurdkhe19j539wii8l.png)](https://asciinema.org/a/cjemrekkurdkhe19j539wii8l)

## Installation

First, clone k8s-devbox repository:
```
git clone https://github.com/ivan4th/k8s-devbox.git
cd k8s-devbox
```

To install the devbox in user's home directory without creating
any VMs or changing configuration of the host machine, use
```
./install.sh home git@github.com:YOUR_GITHUB_USERNAME/kubernetes
```
You'll need to have Docker installed on your machine for this to
work. `home` mode is supported on Linux and Mac OS X, but
unfortunately as of now it only supports bash (zsh support is
planned).

For other installation modes you need to have
[Ansible](http://docs.ansible.com/ansible/intro_installation.html#installation)
>= 2.1.0 installed on your machine. For Mac OS X, you'll also need to
install [Vagrant](https://www.vagrantup.com/) and
[VirtualBox](https://en.wikipedia.org/wiki/VirtualBox).

In case of VM-based installation on Ubuntu, use the following command
to prepare the host:
```
./install.sh host
```
or
```
USE_VIRTUALBOX=1 ./install.sh host
```
to force the use of VirtualBox event if vagrant-libvirt plugin is installed.
You may need to relogin after that.

To install using Vagrant:
```
./install.sh varant git@github.com:YOUR_GITHUB_USERNAME/kubernetes
```
(specify your kubernetes fork)

If you want to force use of VirtualBox for the wrapper VM on Linux, use
```
USE_VIRTUALBOX=1 ./install.sh varant git@github.com:YOUR_GITHUB_USERNAME/kubernetes
```
But note that VirtualBox doesn't support nested virtualization and you
will not be able to use `kube-up` inside your VM.

After installation, you may log into the box via
```
vagrant ssh
```

You can also provision a remote machine to become a k8s dev environment,
but this parts needs some testing:
```
./install.sh remote HOSTNAME git@github.com:YOUR_GITHUB_USERNAME/kubernetes
```

The same goes for the local machine:
```
./install.sh local git@github.com:YOUR_GITHUB_USERNAME/kubernetes
```

You can prepend `USE_VIRTUALBOX=1` to `./install.sh remote ...` or
`./install.sh local ...` to use VirtualBox instead of libvirt for
`vagrant-up`.

**Do not** invoke any of these commands as root, because they need to
use your user account.

## Usage

The following shortcuts are provided in the shell:

```
cdk
```
Chdir to Kubernetes source directory.

```
dind-up [quick] [N]
```
Bring up `N`-node DIND (Docker-in-Docker) cluster. `quick` mode can be
used to start DIND cluster without rebuilding Docker images it uses.
`N` (number of nodes) defaults to 2.

```
dind-down
```
Stop DIND cluster.

```
vagrant-up
```
Bring up a 2-node vagrant based cluster and switches to `vagrant` provider.

```
vagrant-down
```
Bring down the vagrant cluster.

```
list_e2e
```
List available e2e tests

```
e2e [focus]
```
Run e2e test(s). You can specify a filter as regular expression. If
no filter (focus) is specified, the same set of e2e tests as in
upstream CI is used. Note that you need to do `make quick-release` and
start the cluster via either `local-up` or `kube-up` before you can
run e2e tests. Be advised that running e2e tests against `local-up`
cluster may be unreliable.

```
local-up
```
Bring up a local cluster using `hack/local-up-cluster.sh`
with DNS support. You may want to use this command inside
`screen`.

```
use-dind
```
Switch to using DIND cluster that's currently active.

```
use-local
```
Switch to 'local' provider (use with local-up). You may need to
do this in every terminal session you're using to work with
the local cluster.

```
use-vagrant
```
Switch to 'vagrant' provider.

```
update-kubelet
```
Update kubelet on vagrant-based nodes.

```
testit [pkg] [regex]
```
Run unit test(s). `pkg` (package) and `regex` can be used to specify
which tests to run, e.g.
```
testit pkg/api/validation TestValidateEvent
```

```
devhelp
```
Display help on devbox commands.

## "Native" k8s commands

The following commands may be useful for Kubernetes development:

```
make
```
Build Kubernetes binaries.

```
make quick-release
```
Build k8s release for use with kube-up.

```
make test
```
Run unit tests.

## Additional notes

There must be no symlinks in the path to Kubernetes source directory
as this will cause e2e test scripts to fail.

If you started `kube-up` without doing `fix-influxdb` first and
e2e tests refuse to run, you can fix your vagrant cluster using following
commands:
```
cdk
vagrant ssh master -- sudo rm -rf /etc/kubernetes/addons/cluster-monitoring
kubectl delete --now --namespace=kube-system pod monitoring-influxdb-grafana-v3-0
```
