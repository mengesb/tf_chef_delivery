# CHEF Delivery AWS security group - https://github.com/chef-cookbooks/delivery-cluster
resource "aws_security_group" "chef-delivery" {
  name = "chef-delivery"
  description = "CHEF Delivery"
  vpc_id = "${var.aws_vpc_id}"
  tags = {
    Name = "chef-delivery security group"
  }
}
# Allow all from CHEF Server
resource "aws_security_group_rule" "chef-delivery_allow_all_chef-server" {
  type = "ingress"
  from_port = 0
  to_port = 65535
  protocol = "-1"
  source_security_group_id = "${var.chef_server_sg}"
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# Allow all from CHEF Delivery to CHEF Server
resource "aws_security_group_rule" "chef-server_allow_all_chef-delivery" {
  type = "ingress"
  from_port = 0
  to_port = 65535
  protocol = "-1"
  source_security_group_id = "${aws_security_group.chef-delivery.id}"
  security_group_id = "${var.chef_server_sg}"
}
# SSH - all
resource "aws_security_group_rule" "chef-delivery_allow_22_tcp_all" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["${split(",", var.ssh_cidrs)}"]
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
# CHEF Delivery requirements
resource "null_resource" "chef-delivery-requirements" {
  # Create CHEF Delivery user on CHEF Server
  provisioner "remote-exec" {
    connection {
      user = "${var.aws_ami_user}"
      private_key = "${var.aws_private_key_file}"
      host = "${var.chef_server_dns}"
    }
    inline = [
      "echo 'Adding ${var.username}' to CHEF Server",
      "sudo chef-server-ctl user-create ${var.username} ${var.user_firstname} ${var.user_lastname} ${var.user_email} ${base64encode(self.id)} -f /tmp/.chef/${var.username}.pem",
      "sudo chef-server-ctl org-user-add ${var.chef_org_short} ${var.username}",
      "echo Prepared for Delivery provisioning"
    ]
  }
  # Copy back Delivery user pem
  provisioner "local-exec" {
    command  = "scp -o StrictHostKeyChecking=no -i ${var.aws_private_key_file} ${var.aws_ami_user}@${var.chef_server_dns}:/tmp/.chef/${var.username}.pem ${path.cwd}/.chef/${var.username}.pem"
  }
  # Create JSON file for databag
  provisioner "local-exec" {
    command = <<EOF
rm -f ${path.cwd}/.chef/delivery_builder_keys.json
rm -f ${path.cwd}/.chef/builder_key ${path.cwd}/.chef/builder_key.pub ${path.cwd}/.chef/builder_key.pem
rm -f ${path.cwd}/.chef/builder_key_databag ${path.cwd}/.chef/${var.username}_key_databag
cat > ${path.cwd}/.chef/delivery_builder_keys.json <<EOK
{
"id": "delivery_builder_keys",
"builder_key": "BUILDER_KEY",
"delivery_pem": "DELIVERY_PEM"
}
EOK
ssh-keygen -q -t rsa -N '' -b 2048 -f ${path.cwd}/.chef/builder_key
[ -f ${path.cwd}/.chef/builder_key ] && echo 'builder_key generated' || echo "builder_key_missing && exit 1"
ssh-keygen -q -f builder_key -e -m 'PEM' > ${path.cwd}/.chef/builder_key.pem
[ -f ${path.cwd}/.chef/builder_key.pem ] && echo 'builder_key.pem generated' || echo 'builder_key.pem missing' && exit 1
cp ${path.cwd}/.chef/builder_key.pem ${path.cwd}/.chef/builder_key_databag
cp ${path.cwd}/.chef/${var.username}.pem ${path.cwd}/.chef/${var.username}_key_databag
perl -pe 's/\n/\\n/g' -i ${path.cwd}/.chef/builder_key_databag
perl -pe 's/\n/\\n/g' -i ${path.cwd}/.chef/${var.username}_key_databag
cd ${path.cwd}/.chef
perl -pe 's/BUILDER_KEY/`cat builder_key_databag`/ge' -i delivery_builder_keys.json
perl -pe 's/DELIVERY_PEM/`cat ${var.username}_key_databag`/ge' -i delivery_builder_keys.json
knife data bag create keys
knife data bag from file keys ${path.cwd}/.chef/delivery_builder_keys.json --encrypt --secret-file ${var.secret_key_file}
cat ${path.cwd}/.chef/delivery_builder_keys.json
EOF
  }
}
# CHEF Delivery
resource "aws_instance" "chef-delivery" {
  ami = "${var.aws_ami_id}"
  count = "${var.count}"
  instance_type = "${var.aws_flavor}"
  subnet_id = "${var.aws_subnet_id}"
  vpc_security_group_ids = ["${aws_security_group.chef-delivery.id}"]
  key_name = "${var.aws_key_name}"
  tags = {
    Name = "${format("%s-%02d", var.basename, count.index + 1)}"
  }
  root_block_device = {
    delete_on_termination = true
  }
  connection {
    user = "${var.aws_ami_user}"
    private_key = "${var.aws_private_key_file}"
  }
  #provisioner "local-exec" {
  #  command = "mkdir -p ${path.cwd}/.chef"
  #}
  ## Copy over .chef to /tmp
  #provisioner "file" {
  #  source = "${path.cwd}/.chef"
  #  destination = "/tmp"
  #}
  # Create path to delivery license
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/.chef",
      "sudo mkdir -p /var/opt/delivery/license /etc/delivery /etc/chef"
    ]
  }
  # Copy over trusted certificates
  provisioner "file" {
    source = "${path.cwd}/.chef/trusted_certs"
    destination = "/tmp/.chef"
  }
  # Copy in license file
  provisioner "file" {
    source = "${var.license_file}"
    destination = "/tmp/.chef/delivery.license"
  }
  # Put files in proper locations
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/.chef/delivery.license /var/opt/delivery/license",
      "sudo mv /tmp/.chef/trusted_certs /etc/chef",
      "sudo chown -R root:root /var/opt/delivery/license /etc/delivery /etc/chef"
    ]
  }
  # Hostname setup
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
      "sudo rm /tmp/hostname"
    ]
  }
  # Handle iptables
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
      "sudo service iptables restart"
    ]
  }
  # Provision with CHEF
  provisioner "chef" {
    attributes {
      "delivery-cluster" {
        "delivery" {
          "chef_server" = "https://${var.chef_server_dns}/organizations/${var.chef_org_short}"
          "fqdn" = "${self.public_dns}"
        }
      }
    }
    # environment = "_default"
    run_list = ["delivery-cluster::delivery"]
    node_name = "${format("%s-%02d", var.basename, count.index + 1)}"
    secret_key = "${file("${var.secret_key_file}")}"
    server_url = "https://${var.chef_server_dns}/organizations/${var.chef_org_short}"
    validation_client_name = "${var.chef_org_short}-validator"
    validation_key = "${file("${path.cwd}/.chef/${var.chef_org_short}-validator.pem")}"
  }
  # Generate CHEF Delivery enterprise credentials file
  provisioner "remote-exec" {
    inline = [
      "sudo chown -R ${var.aws_ami_user} /tmp/.chef",
      "sudo delivery-ctl create-enterprise ${var.enterprise} --ssh-pub-key-file=/etc/delivery/builder_key.pub > /tmp/.chef/${var.enterprise}.creds",
      "sudo chown -R ${var.aws_ami_user} /tmp/.chef"
    ]
  }
  # Copy back CHEF Delivery enterprise credentials file
  provisioner "local-exec" {
    command  = "scp -o StrictHostKeyChecking=no -i ${var.aws_private_key_file} ${var.aws_ami_user}@${self.public_ip}:/tmp/.chef/${var.enterprise}.creds ${path.cwd}/.chef/${var.enterprise}.creds"
  }
}

