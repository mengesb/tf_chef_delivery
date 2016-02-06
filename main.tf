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
  provisioner "local-exec" {
    command = <<EOF
cat > ${path.cwd}/.chef/delivery_builder_keys <<EOK
"id": "string",
"builder_key": "${file("${path.cwd}/.chef/builder_key")}",
"delivery_pem": "${path.cwd}/.chef/${var.chef_delivery_username}.pem"
EOK
EOF
  }
  provisioner "file" {
    source = "${path.cwd}/.chef"
    destination = "/tmp"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo iptables -F",
      "sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT",
      "sudo iptables -A INPUT -p icmp -j ACCEPT",
      "sudo iptables -A INPUT -i lo -j ACCEPT",
      "sudo iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT",
      "sudo iptables -A INPUT -p tcp -m multiport --dports 80,443,8989 -j ACCEPT",
      "sudo iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited",
      "sudo iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited",
      "sudo service iptables save",
      "sudo service iptables restart",
      "[ -x /usr/sbin/apt-get ] && sudo apt-get install -y git || sudo yum install -y git",
      "sudo mkdir -p /var/opt/delivery/license /etc/delivery /etc/chef",
      "sudo chown -R root:root /tmp/.chef",
      "sudo mv /tmp/.chef/* /etc/delivery/",
      "sudo mv /etc/delivery/trusted_certs /etc/chef/",
      "echo Prepared for Chef Provisioner run"
    ]
  }
  provisioner "chef" {
    attributes {
      "delivery-cluster" {
        "delivery" {
          "chef_server" = "${var.chef_server_url}"
          "fqdn" = "${self.public_ip}"
        }
      }
    }
    # environment = "_default"
    run_list = ["delivery-cluster::delivery"]
    node_name = "${format("%s-%s-%s", var.chef_delivery_name, count.index + 1, var.chef_delivery_enterprise)}"
    secret_key = "${path.cwd}/.chef/encrypted_data_bag_secret"
    server_url = "${var.chef_server_url}"
    validation_client_name = "${var.chef_org}-validator"
    validation_key = "${file("${path.cwd}/.chef/${var.chef_org}-validator.pem")}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo delivery-ctl create-enterprise ${var.chef_delivery_enterprise} --ssh-pub-key-file=/etc/delivery/builder_key.pub > ${path.cwd}/.chef/${var.chef_delivery_enterprise}.creds"
    ]
  }
  provisioner "local-exec" {
    command  = "scp -o StrictHostKeyChecking=no -i ${var.aws_private_key_file} ${var.aws_ami_user}@${self.public_ip}:/tmp/${var.chef_delivery_enterprise}.creds ${path.cwd}/.chef/${var.chef_delivery_enterprise}.creds"
  }
}

