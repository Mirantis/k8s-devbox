K8S_DEVBOX_FULL_ENV="${K8S_DEVBOX_FULL_ENV:-}"
if [ -f /vagrant_devbox ]; then
    K8S_DEVBOX_FULL_ENV=true
fi

if [ -n "$K8S_DEVBOX_FULL_ENV" ]; then
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
# FIXME: refactor this
if [ -d "$HOME/.k8s-devbox/go" ]; then
    # installed via ./install.sh home
    export GOROOT="$HOME/.k8s-devbox/go"
    export PATH="$HOME/.k8s-devbox/bin:$HOME/.k8s-devbox/go-tools/bin:$GOROOT/bin:$KPATH/bin:$KUBERNETES_SRC_DIR/_output/bin:$PATH"
elif [ -d "$HOME/.k8s-devbox/go-tools" ]; then
    # installed via ./install.sh home -nogo
    export PATH="$HOME/.k8s-devbox/go-tools/bin:$GOROOT/bin:$KPATH/bin:$KUBERNETES_SRC_DIR/_output/bin:$PATH"
else
    export PATH="$HOME/go-tools/bin:$KPATH/bin:$KUBERNETES_SRC_DIR/_output/bin:$PATH"
fi

if [ -d "$HOME/.k8s-devbox/bin" ]; then
    export PATH="$HOME/.k8s-devbox/bin:$PATH"
fi

if hash systemctl 2>/dev/null; then
    if systemctl -q is-active virtualbox; then
        export VAGRANT_DEFAULT_PROVIDER=virtualbox
    elif systemctl -q is-active libvirt-bin; then
        export VAGRANT_DEFAULT_PROVIDER=libvirt
    # The following was causing ansible's scp to fail
    # with 'Received message too long'
    #else
    #    echo "WARNING: no active virtualbox or libvirt-bin service detected"
    fi
fi

trace_highlight_start="$(echo -ne "\x1b[100m\x1b[97m"; echo -n "+")"
trace_highlight_end="$(echo -ne "\x1b[49m\x1b[39m")"

function quote_arg {
    if [[ "$arg" =~ " " ]]; then
        echo -n " '$arg'" 1>&2
    else
        echo -n " $arg" 1>&2
    fi
}

function quote_var {
    if [[ "$1" =~ ([^=]+)=(.*\ .*) ]]; then
        echo -n " ${BASH_REMATCH[1]}='${BASH_REMATCH[2]}'"
    else
        echo -n " $1"
    fi
}

function fake_trace {
    echo -n "$trace_highlight_start"
    for arg in "$@"; do
        quote_arg "$arg"
    done
    echo "$trace_highlight_end"
}

function trace {
    # have to use this tricky alternative to set -x becuause
    # we want to highlight the trace lines
    echo -n "$trace_highlight_start"

    if [ "$1" = "export" ]; then
        # don't execute 'export' in a subshell
        echo -n " export"
        shift
        for arg in "$@"; do
            quote_var "$arg"
        done
        echo "$trace_highlight_end"
        export "$@"
        return 0
    fi

    (
        # Use subshell because var assignments are translated
        # to 'export' because "$@" below can't parse them,
        # but we don't want to
        while [[ "$1" =~ "=" ]]; do
            quote_var "$1"
            export "$1"
            shift
        done
        for arg in "$@"; do
            quote_arg "$arg"
        done
        echo "$trace_highlight_end"
        "$@"
    )
}

function escape_test_name() {
    sed 's/[]\$*.^|()[]/\\&/g; s/\s\+/\\s+/g' <<< "$1" | tr -d '\n'
}

function cdk {
    cd "$KUBERNETES_SRC_DIR"
}

if [ -n "$K8S_DEVBOX_FULL_ENV" -a -d "$KUBERNETES_SRC_DIR" ]; then
    cdk
fi

alias kubectl=$KUBERNETES_SRC_DIR/cluster/kubectl.sh

function use-vagrant {
    trace export KUBERNETES_PROVIDER=vagrant
    trace kubectl config use-context vagrant
}

function dind-up {
    cdk
    if [ ! -d dind ]; then
        trace git clone https://github.com/sttts/kubernetes-dind-cluster.git dind
    fi
    if [ "$(uname)" = "Darwin" ]; then
        if [ ! -f _output/dockerized/bin/linux/amd64/hyperkube ]; then
            trace build/run.sh make WHAT=cmd/hyperkube
        fi
    elif [ ! -f _output/bin/hyperkube ]; then
        trace make WHAT=cmd/hyperkube
    fi
    if [ ! -f _output/bin/kubectl ]; then
        make WHAT=cmd/kubectl
    fi
    local -a args
    while true; do
        if [ "${1:-}" = "quick" ]; then
            args=("${args[@]}" DOCKER_IN_DOCKER_SKIP_BUILD=true)
            shift
        elif [[ "${1:-}" =~ [0-9]+ ]]; then
            args=("${args[@]}" NUM_NODES="$1")
            shift
        else
            break
        fi
    done
    trace "${args[@]}" dind/dind-up-cluster.sh
    trace export KUBERNETES_PROVIDER=dind
}

function dind-down {
    cdk
    if [ ! -d dind ]; then
        echo "DIND cluster isn't installed, try dind-up first" 1>& 2
        return 1
    fi
    trace dind/dind-down-cluster.sh
}

function use-dind {
    if [ ! -d dind ]; then
        echo "DIND cluster isn't installed, try dind-up first" 1>& 2
        return 1
    fi
    trace export KUBERNETES_PROVIDER=dind
    trace kubectl config use-context dind
}

function vagrant-up {
    trace make quick-release
    trace KUBERNETES_VAGRANT_USE_NFS=true \
      KUBERNETES_NODE_MEMORY=1024 \
      NUM_NODES=2 \
      KUBERNETES_PROVIDER=vagrant \
      cluster/kube-up.sh
    use-vagrant
}

function vagrant-down {
    trace NUM_NODES=2 \
      KUBERNETES_PROVIDER=vagrant \
      cluster/kube-down.sh
}

function get-ext-ip {
    ip route get 1 | awk '{print $NF;exit}'
}

function list_e2e {
    (
        cdk
        if [ ! -f _output/bin/e2e.test ]; then
            trace make WHAT=test/e2e/e2e.test
        fi
        if [ ! -f _output/bin/ginkgo ]; then
            make WHAT=vendor/github.com/onsi/ginkgo/ginkgo
        fi
        extra_opts=
        if [ $# -gt 0 ]; then
            focus="$(escape_test_name "$1")"
            extra_opts="--ginkgo.focus=${focus}"
        fi
        fake_trace ginkgo _output/bin/e2e.test -- --prefix=e2e --network=e2e --ginkgo.dryRun --ginkgo.noColor --ginkgo.noisyPendings=false $extra_opts '2>&1' '|' 'some_ugly_filter...'
        ginkgo _output/bin/e2e.test -- --prefix=e2e --network=e2e --ginkgo.dryRun --ginkgo.noColor --ginkgo.noisyPendings=false $extra_opts 2>&1 |
            egrep -v '^[•SP ]*$'|awk '/^Will run [0-9]* of [0-9]*/{flag=1;next}/^Ran [0-9]* of [0-9]*/{flag=0}flag'
    )
}

function set_e2e_opts {
    extra_opts=""
    extra_test_args=""
    # work around test_args problems with spaces
    if [ "$KUBERNETES_PROVIDER" = "local" ]; then
        ext_ip="$(get-ext-ip)"
        # thanks to @asalkeld
        trace export KUBE_MASTER_IP="$ext_ip"
        trace export KUBE_MASTER="$ext_ip"
        extra_opts="--check_node_count=false"
        extra_test_args=" --host=http://$KUBE_MASTER_IP:8080"
    elif [ "$KUBERNETES_PROVIDER" = "dind" ]; then
        trace export KUBE_MASTER_IP="localhost"
        trace export KUBE_MASTER="localhost"
        extra_test_args=" --host=https://$KUBE_MASTER_IP:6443"
    fi
}

function e2e {
    (
        cdk
        if [ ! -f _output/bin/e2e.test ]; then
            trace make WHAT=test/e2e/e2e.test
        fi
        if [ ! -f _output/bin/ginkgo ]; then
            make WHAT=vendor/github.com/onsi/ginkgo/ginkgo
        fi
        if [ ! -f _output/bin/kubectl ]; then
            make WHAT=cmd/kubectl
        fi
        set_e2e_opts
        status=0
        if [ $# -gt 0 ]; then
            focus="$(escape_test_name "$1")"
            trace go run hack/e2e.go -v  -check_version_skew=false --test --test_args="--ginkgo.focus=${focus}${extra_test_args}" $extra_opts
        else
            # run 'upstream' set of tests
            trace go run ./hack/e2e.go -v --test  -check_version_skew=false \
               --test_args="--ginkgo.skip=\[Slow\]|\[Serial\]|\[Disruptive\]|\[Flaky\]|\[Feature:.+\]$extra_test_args" $extra_opts
        fi
    )
}

function conformance {
    num_nodes="$(kubectl get nodes -o name|wc -l)"
    set_e2e_opts
    trace GINKGO_PARALLEL_NODES=$num_nodes \
          GINKGO_PARALLEL=y \
          go run hack/e2e.go --v --test -check_version_skew=false \
          --test_args="--ginkgo.focus=\[Conformance\] --ginkgo.skip=\[Serial\]${extra_test_args}" $extra_opts
    # [Serial] tests fail on DIND cluster as of now
    # trace KUBERNETES_CONFORMANCE_TEST=y \
    #       go run hack/e2e.go --v --test -check_version_skew=false \
    #       --test_args="--ginkgo.focus=\[Serial\].*\[Conformance\]${extra_test_args}" $extra_opts
}

function local-up {
    ext_ip="$(get-ext-ip)"
    trace KUBE_ENABLE_CLUSTER_DNS=true \
      KUBELET_HOST="$ext_ip" \
      HOSTNAME_OVERRIDE="$ext_ip" \
      API_HOST="$ext_ip" \
      ALLOW_SECURITY_CONTEXT=true \
      hack/local-up-cluster.sh
}

function use-local {
    ext_ip="$(get-ext-ip)"
    trace export KUBERNETES_PROVIDER=local
    trace kubectl config set-cluster local --server="http://$ext_ip:8080" --insecure-skip-tls-verify=true
    trace kubectl config set-context local --cluster=local
    trace kubectl config use-context local
}

function update-kubelet {
    cdk
    trace make
    for node in node-1 node-2; do
        trace NUM_NODES=2 vagrant ssh $node -- sudo systemctl stop kubelet.service
        trace NUM_NODES=2 vagrant ssh $node -- 'sudo tee /usr/local/bin/kubelet>/dev/null' <_output/bin/kubelet
        trace NUM_NODES=2 vagrant ssh $node -- sudo systemctl start kubelet.service
    done
}

function testit {
    cdk
    if [ $# -eq 0 ]; then
        trace make test
    elif [ $# -eq 1 ]; then
        trace make test WHAT="$1" KUBE_GOFLAGS="-v"
    else
        trace make test WHAT="$1" KUBE_GOFLAGS="-v" KUBE_TEST_ARGS="-run $2"
    fi
}

function devhelp {
    if [ -f /vagrant_devbox ]; then
        cat /etc/motd
    elif [ -f ~/.k8s-devbox/help.txt ]; then
        cat ~/.k8s-devbox/help.txt
    else
        echo "Help file not found" 1>&2
    fi
}

if [ -f ~/.kube/config ] && context_str="$(grep -o 'current-context:.*' ~/.kube/config)" && [[ "$context_str" =~ :\ *([^ ]+) ]]; then
    context="${BASH_REMATCH[1]}"
    case "$context" in
        dind|local|vagrant)
            if [ "${KUBERNETES_PROVIDER:-}" != "$context" ]; then
                if [ -n "$K8S_DEVBOX_FULL_ENV" ]; then
                    trace export KUBERNETES_PROVIDER="$context"
                else
                    export KUBERNETES_PROVIDER="$context"
                fi
            fi
    esac
fi
