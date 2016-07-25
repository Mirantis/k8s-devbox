# Kubernetes development environment

k8s-devbox provides a reproducible development environment
for working on Kubernetes project.

It's currently tested on Ubuntu Xenial (x86_64) and Mac OS X 10.11.

Demo:
[![asciicast](https://asciinema.org/a/55d9hy8ckwz24fs1st3e3l9vy.png)](https://asciinema.org/a/55d9hy8ckwz24fs1st3e3l9vy)

## Installation

First, clone k8s-devbox repository:
```
git clone https://github.com/ivan4th/k8s-devbox.git
cd k8s-devbox
```

You need to have [Ansible](http://docs.ansible.com/ansible/intro_installation.html#installation) >= 2.1.0
installed on your machine. For Mac OS X, you'll also need to install [Vagrant](https://www.vagrantup.com/)
and [VirtualBox](https://en.wikipedia.org/wiki/VirtualBox). On Linux, you need to stop VirtualBox service
if it's running because it conflicts with libvirt:
```
sudo service virtualbox stop
```

On Ubuntu, use the following command to prepare the host:
```
./install.sh host
```
You may need to relogin after that.

To install using Vagrant:
```
./install.sh varant git@github.com:YOUR_GITHUB_USERNAME/kubernetes
```
(specify your kubernetes fork)

After installation, you may log into the box via
```
vagrant ssh
```
On Mac OS X you need to use
```
vagrant ssh -- -l ubuntu
```
(this part will be fixed).

You can also provision a remote machine to become a k8s dev environment,
but this parts needs some testing:
```
./install.sh remote HOSTNAME git@github.com:YOUR_GITHUB_USERNAME/kubernetes
```

The same goes for the local machine:
```
./install.sh local git@github.com:YOUR_GITHUB_USERNAME/kubernetes
```

**Do not** invoke any of these commands as root, because they need to
use your user account.

## Usage

The following shortcuts are provided in the shell:

```
fix-influxdb
```
This applies [my PR](https://github.com/kubernetes/kubernetes/pull/28771) that is
necessary to unbreak vagrant provider. You may need it if you want to run
e2e tests.

```
kube-up
```
Brings up a 2-node vagrant based cluster.

```
kube-down
```
Brings down the vagrant cluster.

```
e2e [focus]
```
Runs e2e test(s). You can specify a filter as regular expression
(unfortunately, spaces arent' currently supported due to escape
problems in k8s scripts). If no filter (focus) is specified,
the smae set of e2e tests as in upstream CI is used.

```
local-up
```
Brings up a local cluster using `hack/local-up-cluster.sh`
with DNS support. You may want to use this command inside
`screen`.

```
use-local
```
Switch to 'local' provider (use with local-up).

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
