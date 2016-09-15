# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  if ENV['USE_VIRTUALBOX'].to_s != '' then
    config.vm.box = "bento/ubuntu-16.04"
  else
    config.vm.box = "nrclark/xenial64-minimal-libvirt"
  end

  config.vm.hostname = "devbox"
  #config.vm.network :private_network, ip: "192.168.128.100"

  config.vm.provider :virtualbox do |v|
    v.memory = 6000
    v.cpus = 2
  end

  config.vm.provider :libvirt do |v|
    # avoid domain name conflicts
    v.random_hostname = true

    # TBD: make these customizable
    v.memory = 16384
    v.cpus = 6
    v.storage :file, :size => '100G'

    # Another possibility for bigger VM disk
    # (harder to deal with when using Ansible LVM modules)
    # v.machine_virtual_size = 40

    v.nested = true
    v.volume_cache = 'none'
    #v.management_network_name = 'vagrant-libvirt-devbox'
    #v.management_network_address = '192.168.128.0/24'
    #v.graphics_port = 5999
  end

  if ENV['USE_VIRTUALBOX'].to_s != '' then
    config.vm.provision "shell",
      inline: "DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python2.7 python2.7-dev && ln -fs /usr/bin/python2.7 /usr/bin/python"
  end

  # ansible_local provisioning doesn't work because libvirt provider
  # fails to provide /vagrant shared holder
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = File.dirname(__FILE__) + "/provisioning/playbook.yml"
    ansible.extra_vars = {
      devbox_type: 'vm'
    }

    # use dirname here because dockerized ansible will have
    # different current directory
    if ENV['USE_VIRTUALBOX'].to_s != '' then
      ansible.extra_vars[:vm_type] = 'virtualbox'
    else
      ansible.extra_vars[:vm_type] = 'libvirt'
    end
    ansible.galaxy_role_file = File.dirname(__FILE__) + "/requirements.yml"

    if ENV['K8S_REPO_URL'].to_s != '' then
      ansible.extra_vars[:k8s_repo_url] = ENV['K8S_REPO_URL']
    end

    # Disable sudo to avoid problems with ssh agent.
    # Sudo is used via 'become' on per-include/per-task basis in playbooks.
    ansible.sudo = false

    # uncomment for Ansible debugging
    # ansible.verbose = "vvv"
  end

  config.ssh.forward_agent = true
end
