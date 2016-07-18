export KPATH=$HOME/work/kubernetes
export GOPATH=$KPATH
export PATH=$HOME/go-tools/bin:$KPATH/bin:$PATH
export KUBERNETES_SRC_DIR=$KPATH/src/k8s.io/kubernetes

alias kubectl=$KUBERNETES_SRC_DIR/cluster/kubectl.sh

# FIXME: should fix the prompt
if [ "$USER" = "vagrant" ]; then
    # In case of vagrant VM, provide a useful default prompt and go to k8s directory
    export GIT_PS1_SHOWDIRTYSTATE=1
    export GIT_PS1_SHOWUNTRACKEDFILES=1
    export PS1='\[\033[1;95m\]\u@\h\[\e[0m\]:\[\e[1;32m\]\w\[\033[0;33m\]$(__git_ps1 " (%s) ")\[\e[0m\]\$ '
    if [ -d "$KUBERNETES_SRC_DIR" ]; then
        cd "$KUBERNETES_SRC_DIR"
    fi
fi

function fix-influxdb {
    (
        cd $KUBERNETES_SRC_DIR
        curl https://patch-diff.githubusercontent.com/raw/kubernetes/kubernetes/pull/28771.patch |
            patch -p1
    )
}

function kube-up {
    (
        set -x
        VAGRANT_DEFAULT_PROVIDER=libvirt \
          KUBERNETES_VAGRANT_USE_NFS=true \
          KUBERNETES_NODE_MEMORY=1024 \
          NUM_NODES=2 \
          KUBERNETES_PROVIDER=vagrant \
          cluster/kube-up.sh
    )
    echo '+ export KUBERNETES_PROVIDER=vagrant'
    export KUBERNETES_PROVIDER=vagrant
}

function kube-down {
    (
        set -x
        VAGRANT_DEFAULT_PROVIDER=libvirt \
          NUM_NODES=2 \
          KUBERNETES_PROVIDER=vagrant \
          cluster/kube-down.sh
    )
}

function e2e {
    if [ $# -gt 0 ]; then
        (
            set -x
            KUBERNETES_PROVIDER=vagrant \
              go run hack/e2e.go -v --test --test_args="--ginkgo.focus=$1"
        )
    else
        # run 'upstream' set of tests
        (
            set -x
            KUBERNETES_PROVIDER=vagrant \
              go run ./hack/e2e.go -v --test \
                --test_args='--ginkgo.skip=\[Slow\]|\[Serial\]|\[Disruptive\]|\[Flaky\]|\[Feature:.+\]'
        )
    fi
}

function get-ext-ip {
    ip route get 1 | awk '{print $NF;exit}'
}

function local-up {
    echo '+ export KUBERNETES_PROVIDER=local'
    export KUBERNETES_PROVIDER=local
    ext_ip="$(get-ext-ip)"
    (
        set -x
        KUBE_ENABLE_CLUSTER_DNS=true \
          KUBELET_HOST="$ext_ip" \
          HOSTNAME_OVERRIDE=$KUBELET_HOST \
          API_HOST=$KUBELET_HOST \
          hack/local-up-cluster.sh
    )
}

function use-local {
    echo '+ export KUBERNETES_PROVIDER=local'
    export KUBERNETES_PROVIDER=local
    ext_ip="$(get-ext-ip)"
    (
        set -x
        kubectl config set-cluster local --server="http://$ext_ip:8080" --insecure-skip-tls-verify=true
        kubectl config set-context local --cluster=local
        kubectl config use-context local
    )
}
