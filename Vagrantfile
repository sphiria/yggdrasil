# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
	# debian jessie box v8.6.1
	config.vm.box = "debian/jessie64"
	config.vm.box_version = "8.6.1"

	# let's expose our folder with config files and utilities
	config.vm.synced_folder "src/", "/vagrant/src/"

	# let's expose some folders in the vm
	config.vm.synced_folder "synced/nginx", "/synced/nginx/", create: true
	config.vm.synced_folder "synced/mediawiki", "/synced/mediawiki/", create: true
	config.vm.synced_folder "restore/", "/synced/restore/", create: true

	# bootstrap script
	config.vm.provision :shell, path: "bootstrap.sh"

	# forward 80 to 4567
	config.vm.network :forwarded_port, guest: 80, host: 4567
end