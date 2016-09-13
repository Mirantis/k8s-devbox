if [ -f /vagrant_devbox ]; then
    # In case of vagrant VM, provide a useful default prompt and go to k8s directory
    # The prompts gets overridden in default ~/.bashrc,
    # so reset it even if this script was already sourced
    export GIT_PS1_SHOWDIRTYSTATE=1
    export GIT_PS1_SHOWUNTRACKEDFILES=1
    export PS1='\[\033[1;95m\]\u@\h\[\e[0m\]:\[\e[1;32m\]\w\[\033[0;33m\]$(__git_ps1 " (%s) ")\[\e[0m\]\$ '
fi

export KPATH=$HOME/work/kubernetes
export GOPATH=$KPATH
export KUBERNETES_SRC_DIR=$KPATH/src/k8s.io/kubernetes
export KUBERNETES_PROVIDER=vagrant
export PATH=$HOME/go-tools/bin:$KPATH/bin:$KUBERNETES_SRC_DIR/cluster:$PATH

if systemctl -q is-active virtualbox; then
    export VAGRANT_DEFAULT_PROVIDER=virtualbox
elif systemctl -q is-active libvirt-bin; then
    export VAGRANT_DEFAULT_PROVIDER=libvirt
# The following was causing ansible's scp to fail
# with 'Received message too long'  
#else
#    echo "WARNING: no active virtualbox or libvirt-bin service detected"
fi

function cdk {
    cd "$KUBERNETES_SRC_DIR"
}

if [ -f /vagrant_devbox -a -d "$KUBERNETES_SRC_DIR" ]; then
    cdk
fi

alias kubectl=$KUBERNETES_SRC_DIR/cluster/kubectl.sh

function use-vagrant {
    set -x
    export KUBERNETES_PROVIDER=vagrant
    kubectl config use-context vagrant
    { set +x; } 2>/dev/null
}

function kube-up {
    set -x
    KUBERNETES_VAGRANT_USE_NFS=true \
      KUBERNETES_NODE_MEMORY=1024 \
      NUM_NODES=2 \
      KUBERNETES_PROVIDER=vagrant \
      cluster/kube-up.sh
    { set +x; } 2>/dev/null
    use-vagrant
}

function kube-down {
    set -x
    NUM_NODES=2 \
      KUBERNETES_PROVIDER=vagrant \
      cluster/kube-down.sh
    { set +x; } 2>/dev/null
}

function get-ext-ip {
    ip route get 1 | awk '{print $NF;exit}'
}

function list_e2e {
    (
        cdk
        # thanks to @asalkeld
        grep -R "framework.KubeDescribe" test/e2e/* | cut -d"(" -f2 | cut -d"," -f1
    )
}

function e2e {
    (
        cdk
        extra_opts=""
        extra_test_args=""
        # work around test_args problems with spaces
        if [ "$KUBERNETES_PROVIDER" = "local" ]; then
            # thanks to @asalkeld
            set -x
            export KUBE_MASTER_IP="$ext_ip"
            export KUBE_MASTER="$ext_ip"
            { set +x; } 2>/dev/null
            extra_opts="--check_node_count=false --check_version_skew=false"
            extra_test_args=" --host=http://$KUBE_MASTER_IP:8080"
            ext_ip="$(get-ext-ip)"
        fi
        if [ $# -gt 0 ]; then
            focus="${1// /\\s}"
            set -x
            go run hack/e2e.go -v --test --test_args="--ginkgo.focus=${focus}${extra_test_args}" $extra_opts
            { set +x; } 2>/dev/null
        else
            # run 'upstream' set of tests
            set -x
            go run ./hack/e2e.go -v --test \
               --test_args="--ginkgo.skip=\[Slow\]|\[Serial\]|\[Disruptive\]|\[Flaky\]|\[Feature:.+\]$extra_test_args" $extra_opts
            { set +x; } 2>/dev/null
        fi
    )
}

function local-up {
    ext_ip="$(get-ext-ip)"
    set -x
    export KUBERNETES_PROVIDER=local
    { set +x; } 2>/dev/null
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
    ext_ip="$(get-ext-ip)"
    set -x
    export KUBERNETES_PROVIDER=local
    kubectl config set-cluster local --server="http://$ext_ip:8080" --insecure-skip-tls-verify=true
    kubectl config set-context local --cluster=local
    kubectl config use-context local
    { set +x; } 2>/dev/null
}

function update-kubelet {
    cdk
    set -x
    make
    for node in node-1 node-2; do
        NUM_NODES=2 vagrant ssh $node -- sudo systemctl stop kubelet.service
        NUM_NODES=2 vagrant ssh $node -- 'sudo tee /usr/local/bin/kubelet>/dev/null' <_output/bin/kubelet
        NUM_NODES=2 vagrant ssh $node -- sudo systemctl start kubelet.service
    done
    { set +x; } 2>/dev/null
}
