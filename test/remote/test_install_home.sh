#!/bin/bash
. test/remote/common.sh

./install.sh home https://github.com/kubernetes/kubernetes.git
devbox-test-e2e-simple
