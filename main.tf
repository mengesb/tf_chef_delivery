# CHEF Delivery AWS security group - https://github.com/chef-cookbooks/delivery-cluster
resource "aws_security_group" "chef-delivery" {
  name = "chef-delivery"
  description = "CHEF Delivery"
  vpc_id = "${var.aws_vpc_id}"
  tags = {
    Name = "chef-delivery security group"
  }
}
# SSH - all
resource "aws_security_group_rule" "chef-delivery_allow_22_tcp_all" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# HTTP (nginx)
resource "aws_security_group_rule" "chef-delivery_allow_80_tcp_all" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# HTTPS (nginx)
resource "aws_security_group_rule" "chef-delivery_allow_443_tcp_all" {
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# Delivery GIT
resource "aws_security_group_rule" "chef-delivery_allow_8989_tcp_all" {
  type = "ingress"
  from_port = 8989
  to_port = 8989
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# Egress: ALL
resource "aws_security_group_rule" "chef-delivery_allow_all" {
  type = "egress"
  from_port = 0
  to_port = 65535
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# CHEF Delivery
resource "aws_instance" "chef-delivery" {
  ami = "${var.aws_ami_id}"
  instance_type = "${var.aws_flavor}"
  subnet_id = "${var.aws_subnet_id}"
  vpc_security_group_ids = ["${aws_security_group.chef-delivery.id}"]
  key_name = "${var.aws_key_name}"
  tags = {
    Name = "${format("%s-%02d-%s", var.delivery_basename, count.index + 1, var.chef_org_short)}"
  }
  root_block_device = {
    delete_on_termination = true
  }
  connection {
    user = "${var.aws_ami_user}"
    private_key = "${var.aws_private_key_file}"
  }
  provisioner "local-exec" {
    command = "mkdir -p ${path.cwd}/.chef/keys"
  }
  provisioner "remote-exec" {
    connection {
      user = "${var.aws_ami_user}"
      private_key = "${var.aws_private_key_file}"
      host = "${var.chef_server_public_dns}"
    }
    inline = [
      "echo 'Adding ${var.username}' to CHEF Server",
      "sudo chef-server-ctl user-create ${var.username} Delivery User delivery@domain.tld ${base64encode(self.id)} -f /tmp/.chef/keys/${var.username}.pem",
      "sudo chef-server-ctl org-user-add ${var.chef_org_short} ${var.username}",
      "echo Prepared for Delivery provisioning"
    ]
  }
  provisioner "local-exec" {
    command  = "scp -o StrictHostKeyChecking=no -i ${var.aws_private_key_file} ${var.aws_ami_user}@${var.chef_server_public_dns}:/tmp/.chef/keys/${var.username}.pem ${path.cwd}/.chef/keys/${var.username}.pem"
  }
  # Ugly PERL hack because you can't source file() unless it exists before runtime
  # https://github.com/hashicorp/terraform/issues/3354
  provisioner "local-exec" {
    command = <<EOF
cat > ${path.cwd}/.chef/delivery_builder_keys.json <<EOK
{
"id": "delivery_builder_keys",
"builder_key": "BUILDER_KEY",
"delivery_pem": "DELIVERY_PEM"
}
EOK
# Encryption key
openssl rand -base64 512 | tr -d '\r\n' > ${path.cwd}/.chef/keys/encrypted_data_bag_secret
# SSH Keys
ssh-keygen -t rsa -N '' -b 2048 -f ${path.cwd}/.chef/keys/builder_key
ssh-keygen -f builder_key -e -m pem > ${path.cwd}/.chef/keys/builder_key.pem
cd ${path.cwd}/.chef/keys
cp builder_key.pem builder_key_databag
cp ${var.username}.pem ${var.username}_pem_databag
perl -pe 's/\n/\\n/g' -i builder_key_databag
perl -pe 's/\n/\\n/g' -i ${var.username}_pem_databag
perl -pe 's/BUILDER_KEY/`cat builder_key_databag`/ge' -i ../delivery_builder_keys.json
perl -pe 's/DELIVERY_PEM/`cat ${var.username}_pem_databag`/ge' -i ../delivery_builder_keys.json
rm builder_key_databag ${var.username}_pem_databag
cd ../..
# Create the data-bag keys
knife data bag create keys 
knife data bag from file keys ${path.cwd}/.chef/delivery_builder_keys.json --encrypt --secret-file ${path.cwd}/.chef/keys/encrypted_data_bag_secret
EOF
  }
  # Copy over .chef to /tmp
  provisioner "file" {
    source = "${path.cwd}/.chef"
    destination = "/tmp"
  }
  # Copy in license file
  provisioner "file" {
    source = "${var.license_file}"
    destination = "/tmp/.chef/delivery.license"
  }
  # Basic Setup
  provisioner "remote-exec" {
    inline = [
      "EC2IPV4=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)",
      "echo $EC2IPV4",
      "EC2FQDN=$(curl http://169.254.169.254/latest/meta-data/public-hostname)",
      "EC2HOST=$(echo $EC2FQDN | sed 's/..*//')",
      "EC2DOMA=$(echo $EC2FQDN | sed \"s/$EC2HOST.//\")",
      "sudo sed -i '/localhost/{n;s/^/${self.public_ip} ${self.public_dns}\\n/}' /etc/hosts",
      "[ -f /etc/sysconfig/network ] && sudo hostname ${self.public_dns} || sudo hostname $EC2HOST",
      "echo ${self.public_dns}|sed 's/\\..*//' > /tmp/hostname",
      "sudo chown root:root /tmp/hostname",
      "[ -f /etc/sysconfig/network ] && sudo sed -i 's/^HOSTNAME.*/HOSTNAME=${self.public_dns}/' /etc/sysconfig/network || sudo cp /tmp/hostname /etc/hostname",
      "sudo rm /tmp/hostname",
      "sudo iptables -F",
      "sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT",
      "sudo iptables -A INPUT -p icmp -j ACCEPT",
      "sudo iptables -A INPUT -i lo -j ACCEPT",
      "sudo iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT",
      "sudo iptables -A INPUT -p tcp -m multiport --dports 80,443,8989 -j ACCEPT",
      "sudo iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited",
      "sudo iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited",
      "sudo service iptables save",
      "sudo service iptables restart"
    ]
  }
  # Setup
  provisioner "remote-exec" {
    inline = [
      "[ -x /usr/sbin/apt-get ] && sudo apt-get install -y git || sudo yum install -y git",
      "sudo mkdir -p /var/opt/delivery/license /etc/delivery /etc/chef",
      "sudo mv /tmp/.chef/delivery.license /var/opt/delivery/license",
      "sudo cp -R /tmp/.chef/* /etc/delivery/",
      "sudo cp -R /tmp/.chef/keys/* /etc/delivery/",
      "sudo cp -R /tmp/.chef/* /etc/chef/",
      "sudo mv /etc/delivery/trusted_certs /etc/chef/",
      "sudo chown -R root:root /etc/delivery /etc/chef /var/opt/delivery",
      "echo Prepared for Chef Provisioner run"
    ]
  }
  provisioner "chef" {
    attributes {
      "delivery-cluster" {
        "delivery" {
          "chef_server" = "${var.chef_server_url}"
          "fqdn" = "${self.public_dns}"
        }
      }
    }
    # environment = "_default"
    run_list = ["delivery-cluster::delivery"]
    node_name = "${format("%s-%02d-%s", var.delivery_basename, count.index + 1, var.enterprise)}"
    # secret_key = "${file("${path.cwd}/.chef/keys/encrypted_data_bag_secret")}"
    server_url = "${var.chef_server_url}"
    validation_client_name = "${var.chef_org_short}-validator"
    validation_key = "${file("${path.cwd}/.chef/keys/${var.chef_org_short}-validator.pem")}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo chown -R ${var.aws_ami_user} /tmp/.chef",
      "sudo delivery-ctl create-enterprise ${var.enterprise} --ssh-pub-key-file=/etc/delivery/builder_key.pub > /tmp/.chef/${var.enterprise}.creds",
      "sudo chown -R ${var.aws_ami_user} /tmp/.chef"
    ]
  }
  provisioner "local-exec" {
    command  = "scp -o StrictHostKeyChecking=no -i ${var.aws_private_key_file} ${var.aws_ami_user}@${self.public_ip}:/tmp/.chef/${var.enterprise}.creds ${path.cwd}/.chef/${var.enterprise}.creds"
  }
}

