#!/bin/bash
set -u -e

# workaround for https://github.com/ansible/ansible-modules-core/issues/3706
# (fixed in Ansible 2.1.1).
# joshualund.golang role fails without this
export LANG=C
export LC_ALL=C
unset LANGUAGE

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nogo=
k8s_repo_url=
ansible_via_docker=
target_hostname=
provider_args=
vm_type=libvirt
USE_VIRTUALBOX="${USE_VIRTUALBOX:-}"
export ANSIBLE_ROLES_PATH=$script_dir/provisioning/roles

function usage {
    echo "Usage:" 1>&2
    echo "  ./install.sh local [K8S_REPO_URL]        - provision the local machine"
    echo "  ./install.sh remote HOST [K8S_REPO_URL]  - provision the remote host"
    echo "  ./install.sh home [-nogo] [K8S_REPO_URL] - install in current user's home directory"
    echo "                                             (WiP; currently bash-only)"
    echo "                                             -nogo prevents the script from installing Go"
    echo "  ./install.sh vagrant [K8S_REPO_URL]      - install inside a Vagrant VM"
    echo "  ./install.sh host                        - prepare host machine for devbox VM"
    exit 1
}

function install_roles {
    mkdir -p $ANSIBLE_ROLES_PATH
    ansible-galaxy install -r requirements.yml
}

function update_profile {
    if [ ! -f "$1" ]; then
        return 1
    fi
    if ! grep -q '#added-by-k8s-devbox' "$1"; then
        echo >>"$1"
        echo ". '$devbox_dir'/k8s-devenv.sh #added-by-k8s-devbox" >> "$1"
    fi
}

function install_go {
    rm -rf "$devbox_dir/go"
    cd "$devbox_dir"
    if [ "$(uname)" == "Darwin" ]; then
      go_tarball=go1.7.1.darwin-amd64.tar.gz
      go_tarball_sha256="9fd80f19cc0097f35eaa3a52ee28795c5371bb6fac69d2acf70c22c02791f912"
    else
      go_tarball=go1.7.1.linux-amd64.tar.gz
      go_tarball_sha256="43ad621c9b014cde8db17393dc108378d37bc853aa351a6c74bf6432c1bbd182"
    fi
    rm -f "$go_tarball"
    wget https://storage.googleapis.com/golang/"$go_tarball"
    if ! echo "$go_tarball_sha256  $go_tarball" | sha256sum -c -; then
        echo "Go tarball checksum verification failed" 1>&2
        exit 1
    fi
    tar -xzf "$go_tarball"
    rm -f "$go_tarball"
    export GOROOT="$devbox_dir/go"
    export PATH="$devbox_dir/go/bin:$PATH"
    CGO_ENABLED=0 go install -a -installsuffix cgo std
}

function install_go_tools {
    if [ -z "$nogo" -o -z "${GOPATH:-}" ]; then
        mkdir -p "$devbox_dir/go-tools"
        export GOPATH="$devbox_dir/go-tools"
    fi
    go get -u github.com/tools/godep
    go get -u github.com/jteeuwen/go-bindata/go-bindata
}

function install_to_home_dir {
    devbox_dir="$HOME"/.k8s-devbox
    mkdir -p "$devbox_dir"
    cp "$script_dir"/provisioning/files/k8s-devenv.sh "$devbox_dir"
    cp "$script_dir"/provisioning/files/motd "$devbox_dir/help.txt"
    # TBD: verify prereqs
    if [ -z "$nogo" ]; then
        install_go
    fi
    install_go_tools
    # based on from https://github.com/moovweb/gvm/blob/604e702e2a155b33c2f217f1f4931188344d4926/binscripts/gvm-installer#L96
    if [ -n "${ZSH_NAME:-}" ]; then
        echo "Sorry, zsh isn't supported yet" 1>&2
        exit 1
    elif [ "$(uname)" == "Linux" ]; then
        update_profile "$HOME/.bashrc" || update_profile "$HOME/.bash_profile"
    elif [ "$(uname)" == "Darwin" ]; then
        update_profile "$HOME/.profile" || update_profile "$HOME/.bash_profile"
    fi
    if [ -n "$k8s_repo_url" -a ! -d $HOME/work/kubernetes/src/k8s.io/kubernetes ]; then
        mkdir -p "$HOME/work/kubernetes/src/k8s.io"
        git clone "$k8s_repo_url" "$HOME/work/kubernetes/src/k8s.io/kubernetes"
    fi
    echo 1>&2
    echo "Please restart your shell to start using k8s-devbox or use . ~/.k8s-devbox/k8s-devenv.sh" 1>&2
}

function install_using_vagrant {
    if ! hash vagrant 2>/dev/null; then
        echo "You need to install Vagrant" 1>&2
        exit 1
    fi

    if [ -z "$USE_VIRTUALBOX" ] && vagrant plugin list | grep -q '^vagrant-libvirt'; then
        export VAGRANT_DEFAULT_PROVIDER=libvirt
        provider_args="--provider=libvirt"
    else
        export USE_VIRTUALBOX=1
    fi

    if [ -n "$USE_VIRTUALBOX" ]; then
        vm_type=virtualbox
    fi

    # https://kushaldas.in/posts/storage-volume-error-in-libvirt-with-vagrant.html
    # FIXME: happens too often for me for some reason
    virsh pool-refresh tmp >& /dev/null || true
    K8S_REPO_URL=$k8s_repo_url vagrant up $provider_args
}

function provision_vm_host {
    ansible-playbook -i localhost, -c local --ask-sudo-pass \
                     -e "devbox_type=vm_host vm_type=$vm_type" provisioning/playbook.yml
}

function install_via_ansible {
    conn_opts="$*"
    install_roles
    extra_vars="devbox_type=host vm_type=$vm_type"
    if [ -n "$k8s_repo_url" ]; then
        extra_vars="$extra_vars k8s_repo_url=$k8s_repo_url"
    fi
    ansible-playbook $conn_opts --ask-sudo-pass \
                     -e "$extra_vars" provisioning/playbook.yml
}

function install_locally {
    install_via_ansible -i localhost, -c local
}

function install_remotely {
    install_via_ansible -i "$target_hostname", --ssh-extra-args="-oForwardAgent=yes"
}

if [ $# -gt 0 ]; then
    if [ "$1" = "-d" ]; then
        ansible_via_docker=y
        shift
    fi
fi

if [ $# -eq 0 ]; then
    usage
fi

cmd="$1"
shift

if [ "$cmd" = "remote" ]; then
    if [ $# -eq 0 ]; then
        echo "must specify target hostname" 1>& 2
    fi
    target_hostname="$1"
    shift
fi

if [ "${1:-}" = "-nogo" ]; then
    nogo=1
    shift
fi

k8s_repo_url=
if [ $# -gt 0 ]; then
    k8s_repo_url="$1"
fi

if ! hash ansible-playbook 2>/dev/null; then
    ansible_via_docker=y
fi

if [ -n "$ansible_via_docker" ]; then
    echo "WiP: ansible invocation via docker doesn't work currently due to ssh & file perm problems" 1>& 2
    exit 1
    # export PATH="$script_dir/ansible-via-docker:$PATH"
fi

case "$cmd" in
    vagrant)
        install_using_vagrant
        ;;
    host)
        provision_vm_host
        ;;
    local)
        install_locally
        ;;
    remote)
        install_remotely
        ;;
    home)
        install_to_home_dir
        ;;
    *)
        usage
        ;;
esac
