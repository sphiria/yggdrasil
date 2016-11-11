# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
	# debian jessie box v8.6.1
	config.vm.box = "debian/jessie64"
	config.vm.box_version = "8.6.1"

	# let's expose mediawiki & nginx to folders in the vm
	config.vm.synced_folder "mediawiki/", "/synced/mediawiki"
	config.vm.synced_folder "nginx/", "/synced/nginx"

	# bootstrap script
	config.vm.provision :shell, path: "bootstrap.sh"

	# forward 80 to 4567
	config.vm.network :forwarded_port, guest: 80, host: 4567
end