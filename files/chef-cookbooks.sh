#!/usr/bin/env bash
[ -x /usr/bin/yum ] && sudo yum -q -y install git || sudo apt-get -qq install git
sudo rm -rf /var/chef/cookbooks
sudo mkdir -p /var/chef/cookbooks
for DEP in apt apt-chef build-essential   ; do curl -sL https://supermarket.chef.io/cookbooks/${DEP}/download | sudo tar xzC /var/chef/cookbooks; done
for DEP in chef-ingredient git 7-zip      ; do curl -sL https://supermarket.chef.io/cookbooks/${DEP}/download | sudo tar xzC /var/chef/cookbooks; done
for DEP in chef-splunk chef-sugar cron    ; do curl -sL https://supermarket.chef.io/cookbooks/${DEP}/download | sudo tar xzC /var/chef/cookbooks; done
for DEP in delivery-base delivery_build   ; do sudo git clone -q --depth=1 https://github.com/chef-cookbooks/${DEP} /var/chef/cookbooks/${DEP}   ; done
for DEP in delivery-cluster               ; do sudo git clone -q --depth=1 https://github.com/chef-cookbooks/${DEP} /var/chef/cookbooks/${DEP}   ; done
for DEP in firewall hostsfile packagecloud; do curl -sL https://supermarket.chef.io/cookbooks/${DEP}/download | sudo tar xzC /var/chef/cookbooks; done
for DEP in push-jobs system yum yum-chef  ; do curl -sL https://supermarket.chef.io/cookbooks/${DEP}/download | sudo tar xzC /var/chef/cookbooks; done
for DEP in chef-vault windows             ; do curl -sL https://supermarket.chef.io/cookbooks/${DEP}/download | sudo tar xzC /var/chef/cookbooks; done
sudo cp -rp /var/chef/cookbooks/delivery-cluster/vendor/chef-server-12 /var/chef/cookbooks
sudo chown -R root:root /var/chef/cookbooks
echo Finished
