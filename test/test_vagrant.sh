#!/bin/bash
set -u -e -x
tempdir="$(mktemp -d)"
cp -av "$(dirname "${BASH_SOURCE[0]}")/.." "$tempdir"/devbox
cd "$tempdir"/devbox
trap 'vagrant destroy || true; rm -rf "$tempdir"' EXIT

./install.sh vagrant https://github.com/kubernetes/kubernetes.git
vagrant ssh -- '
export PATH="/usr/local/go/bin:$PATH"
. /etc/profile.d/k8s-devenv.sh
dind-up &&
list_e2e DNS | grep "should provide DNS for the cluster" &&
e2e "existing RC" &&
dind-down &&
dind-up quick 6 &&
conformance
dind-down &&
testit pkg/api/validation TestValidateEvent
'

# TODO: test local-up
# TODO: test vagrant-up
