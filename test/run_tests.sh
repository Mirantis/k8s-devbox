#!/bin/bash
set -u -e
for name in test_*.sh; do
    echo "************* $name"
    if (time ./$name) >&"$name".log; then
        echo "************* OK"
    else
        echo "************* FAIL"
    fi
    # FIXME: workaround for vagrant-libvirt problem
    if hash virsh 2>/dev/null; then
        virsh pool-refresh tmp >&/dev/null || true
    fi
done
