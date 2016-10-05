#!/usr/bin/env bash
set -u -e -x -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ../scripts/gce.sh

devbox::gce::cleanup-test-stuff
devbox::gce::make-provisioned-image "${test_image_name}" provision.sh

# TBD: /bin/bash ++ rm 'mapfile'
