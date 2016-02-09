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
# Provision Delivery
resource "aws_instance" "chef-delivery" {
  ami = "${var.aws_ami_id}"
  instance_type = "${var.aws_flavor}"
  subnet_id = "${var.aws_subnet_id}"
  vpc_security_group_ids = ["${aws_security_group.chef-delivery.id}"]
  key_name = "${var.aws_key_name}"
  tags = {
    Name = "${format("%s-%02d-%s", var.chef_delivery_name, count.index + 1, var.chef_org)}"
  }
  root_block_device = {
    delete_on_termination = true
  }
  connection {
    user = "${var.aws_ami_user}"
    private_key = "${var.aws_private_key_file}"
  }
  # Ugly PERL hack because you can't source file() unless it exists before runtime
  # https://github.com/hashicorp/terraform/issues/3354
  provisioner "local-exec" {
    command = <<EOF
cd ${path.cwd}/.chef
cat > delivery_builder_keys <<EOK
"id": "delivery_builder_keys",
"builder_key": "BUILDER_KEY",
"delivery_pem": "${path.cwd}/.chef/${var.chef_delivery_username}.pem"
EOK
perl -pe 's/BUILDER_KEY/`cat builder_key`/ge' -i ${path.cwd}/.chef/delivery_builder_keys
EOF
  }
  provisioner "file" {
    source = "${path.cwd}/.chef"
    destination = "/tmp"
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
  # Setup Packages
  provisioner "remote-exec" {
    inline = [
      "[ -x /usr/sbin/apt-get ] && sudo apt-get install -y git || sudo yum install -y git",
      "sudo mkdir -p /var/opt/delivery/license /etc/delivery /etc/chef",
      "sudo chown -R root:root /tmp/.chef",
      "sudo mv /tmp/.chef/* /etc/delivery/",
      "sudo mv /etc/delivery/trusted_certs /etc/chef/",
      "echo Prepared for Chef Provisioner run"
    ]
  }
  provisioner "file" {
    source = "${var.chef_delivery_license}"
    destination = "/tmp/delivery.license"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/delivery.license /var/opt/delivery/license/",
      "sudo chown root:root /var/opt/delivery/license/delivery.license"
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
    node_name = "${format("%s-%02d-%s", var.chef_delivery_name, count.index + 1, var.chef_delivery_enterprise)}"
    secret_key = "${path.cwd}/.chef/encrypted_data_bag_secret"
    server_url = "${var.chef_server_url}"
    validation_client_name = "${var.chef_org}-validator"
    validation_key = "${file("${path.cwd}/.chef/${var.chef_org}-validator.pem")}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo chown -R ${var.aws_ami_user} /tmp/.chef",
      "sudo delivery-ctl create-enterprise ${var.chef_delivery_enterprise} --ssh-pub-key-file=/etc/delivery/builder_key.pub > /tmp/.chef/${var.chef_delivery_enterprise}.creds",
      "sudo chown -R ${var.aws_ami_user} /tmp/.chef"
    ]
  }
  provisioner "local-exec" {
    command  = "scp -o StrictHostKeyChecking=no -i ${var.aws_private_key_file} ${var.aws_ami_user}@${self.public_ip}:/tmp/.chef/${var.chef_delivery_enterprise}.creds ${path.cwd}/.chef/${var.chef_delivery_enterprise}.creds"
  }
}

