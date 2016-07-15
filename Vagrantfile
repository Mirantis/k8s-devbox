# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "nrclark/xenial64-minimal-libvirt"

  config.vm.hostname = "devbox"
  config.vm.network :private_network, ip: "192.168.124.100"

  config.vm.provider :libvirt do |v|
    v.memory = 16384
    v.cpus = 6
    v.nested = true
    v.volume_cache = 'none'
    v.management_network_name = 'vagrant-libvirt-new'
    v.management_network_address = '192.168.124.0/24'
    v.storage :file, :size => '100G'
    #v.machine_virtual_size = 40
  end

  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "provisioning/playbook.yml"
    # ansible.verbose = "vvv"
    # disable sudo to avoid problems with ssh agent
    ansible.sudo = false
  end

  config.ssh.forward_agent = true

end
