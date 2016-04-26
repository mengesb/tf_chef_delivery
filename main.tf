# Chef Delivery AWS security group - https://github.com/chef-cookbooks/delivery-cluster
resource "aws_security_group" "chef-delivery" {
  name        = "${var.hostname}.${var.domain} security group"
  description = "Delivery server ${var.hostname}.${var.domain}"
  vpc_id      = "${var.aws_vpc_id}"
  tags        = {
    Name      = "${var.hostname}.${var.domain} security group"
  }
}
# SSH - allowed_cidrs
resource "aws_security_group_rule" "chef-delivery_allow_22_tcp_all" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["${split(",", var.allowed_cidrs)}"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# HTTP (nginx)
resource "aws_security_group_rule" "chef-delivery_allow_80_tcp_all" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# HTTPS (nginx)
resource "aws_security_group_rule" "chef-delivery_allow_443_tcp_all" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# Delivery GIT
resource "aws_security_group_rule" "chef-delivery_allow_8989_tcp_all" {
  type        = "ingress"
  from_port   = 8989
  to_port     = 8989
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# Egress: ALL
resource "aws_security_group_rule" "chef-delivery_allow_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# AWS settings
provider "aws" {
  access_key  = "${var.aws_access_key}"
  secret_key  = "${var.aws_secret_key}"
  region      = "${var.aws_region}"
}
#
# Provisioning template
#
resource "template_file" "attributes-json" {
  template    = "${file("${path.module}/files/attributes-json.tpl")}"
  vars {
    chef_fqdn = "${var.chef_fqdn}"
    chef_org  = "${var.chef_org}"
    host      = "${var.hostname}"
    domain    = "${var.domain}"
  }
}
# Delivery builder databag template
resource "template_file" "delivery_builder_keys-json" {
  template = "${file("${path.module}/files/delivery-builder-keys-json.tpl")}"
  vars {
    username  = "${var.username}"
  }
}
# Purge local cache directory
resource "null_resource" "clean-slate" {
  provisioner "local-exec" {
    command = "rm -rf .delivery ; mkdir -p .delivery"
  }
}
#
# Wait on
#
resource "null_resource" "wait_on" {
  provisioner "local-exec" {
    command = "echo Waited on ${var.wait_on} before proceeding"
  }
}
# Delivery user required in Chef organization
resource "null_resource" "delivery-user" {
  depends_on = ["null_resource.clean-slate","null_resource.wait_on"]
  connection {
    user        = "${lookup(var.ami_usermap, var.ami_os)}"
    private_key = "${var.aws_private_key_file}"
    host        = "${var.chef_fqdn}"
  }
  # Create user
  provisioner "remote-exec" {
    inline = [
      "rm -rf .delivery ; mkdir .delivery",
      "sudo chef-server-ctl org-user-remove ${var.chef_org} ${var.username} --force -y || echo OK",
      "sudo chef-server-ctl user-delete ${var.username} -y || echo OK",
      "sudo chef-server-ctl user-create ${var.username} ${var.user_firstname} ${var.user_lastname} ${var.user_email} ${base64sha256(self.id)} -f .delivery/${var.username}.pem",
      "sudo chef-server-ctl org-user-add ${var.chef_org} ${var.username} -a",
      "sudo chown -R ${lookup(var.ami_usermap, var.ami_os)} .delivery",
    ]
  }
  # Copy back private key
  provisioner "local-exec" {
    command = "scp -o stricthostkeychecking=no -i ${var.aws_private_key_file} ${lookup(var.ami_usermap, var.ami_os)}@${var.chef_fqdn}:.delivery/${var.username}.pem .delivery/${var.username}.pem"
  }
}
# Generate build user and data bag information
resource "null_resource" "builder-key" {
  depends_on = ["null_resource.delivery-user","null_resource.wait_on"]
  provisioner "local-exec" {
    command = "ssh-keygen -q -t rsa -N '' -b 2048 -f .delivery/builder_key"
  }
  provisioner "local-exec" {
    command = <<-EOC
      cat > .delivery/delivery_builder_keys.json <<EOF
      ${template_file.delivery_builder_keys-json.rendered}
      EOF
      sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\\n/g' .delivery/builder_key > .delivery/builder_key_databag
      sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\\n/g' .delivery/${var.username}.pem > .delivery/delivery_key_databag
      cd .delivery && perl -pe 's/text1/`cat builder_key_databag`/ge' -i delivery_builder_keys.json && cd ..
      cd .delivery && perl -pe 's/text2/`cat delivery_key_databag`/ge' -i delivery_builder_keys.json && cd ..
      rm -rf .delivery/builder_key_databag .delivery/delivery_key_databag
      knife data bag create keys
      knife data bag from file keys .delivery/delivery_builder_keys.json --encrypt --secret-file ${var.secret_key_file}
      EOC
  }
}
# Delivery cookbooks
resource "null_resource" "delivery-cookbooks" {
  depends_on = ["null_resource.clean-slate","null_resource.wait_on"]
  provisioner "local-exec" {
    command = "git clone https://github.com/chef-cookbooks/delivery-cluster cookbooks/delivery-cluster"
  }
  provisioner "local-exec" {
    command = "rm -rf cookbooks/delivery-cluster/.chef"
  }
  provisioner "local-exec" {
    command = "cd cookbooks/delivery-cluster && berks install && berks upload"
  }
  provisioner "local-exec" {
    command = "rm -rf cookbooks"
  }
}
#
# Provision server
#
resource "aws_instance" "chef-delivery" {
  depends_on    = ["null_resource.builder-key","null_resource.delivery-user","null_resource.delivery-cookbooks"]
  ami           = "${lookup(var.ami_map, format("%s-%s", var.ami_os, var.aws_region))}"
  count         = "${var.server_count}"
  instance_type = "${var.aws_flavor}"
  associate_public_ip_address = "${var.public_ip}"
  subnet_id     = "${var.aws_subnet_id}"
  vpc_security_group_ids = ["${aws_security_group.chef-delivery.id}"]
  key_name      = "${var.aws_key_name}"
  tags = {
    Name        = "${var.hostname}.${var.domain}"
    Description = "${var.tag_description}"
  }
  root_block_device = {
    delete_on_termination = "${var.root_delete_termination}"
  }
  connection {
    user        = "${lookup(var.ami_usermap, var.ami_os)}"
    private_key = "${var.aws_private_key_file}"
    host        = "${self.public_ip}"
  }
  # Clean up any potential node/client conflicts
  provisioner "local-exec" {
    command = "knife node-delete   ${var.hostname}.${var.domain} -y -c ${var.knife_rb} ; echo OK"
  }
  provisioner "local-exec" {
    command = "knife client-delete ${var.hostname}.${var.domain} -y -c ${var.knife_rb} ; echo OK"
  }
  # Handle iptables
  provisioner "remote-exec" {
    inline = [
      "sudo service iptables stop",
      "sudo chkconfig iptables off",
      "sudo ufw disable",
      "echo Say WHAT one more time"
    ]
  }
  # Prepare some directories to stage files
  provisioner "remote-exec" {
    inline = [
      "mkdir -p .delivery",
      "sudo mkdir -p /var/opt/delivery/license /etc/delivery /etc/chef"
    ]
  }
  # Transfer in required files
  provisioner "file" {
    source      = "${var.delivery_license}"
    destination = ".delivery/delivery.license"
  }
  provisioner "file" {
    source      = ".delivery/${var.username}.pem"
    destination = ".delivery/${var.username}.pem"
  }
  provisioner "file" {
    source      = ".delivery/builder_key"
    destination = ".delivery/builder_key"
  }
  provisioner "file" {
    source      = ".delivery/builder_key.pub"
    destination = ".delivery/builder_key.pub"
  }
  # Move files to final location
  provisioner "remote-exec" {
    inline = [
      "sudo mv .delivery/delivery.license /var/opt/delivery/license",
      "sudo mv .delivery/* /etc/delivery",
      "sudo chown -R root:root /etc/delivery/builder_key /etc/delivery/builder_key.pub /etc/delivery/delivery.pem",
      "sudo chmod 0666 /etc/delivery/builder_key /etc/delivery/builder_key.pub /etc/delivery/delivery.pem",
      "sudo chown -R root:root /var/opt/delivery/license /etc/delivery /etc/chef"
    ]
  }
  # Provision with Chef
  provisioner "chef" {
    attributes_json = "${template_file.attributes-json.rendered}"
    environment     = "_default"
    log_to_file     = "${var.log_to_file}"
    node_name       = "${var.hostname}.${var.domain}"
    run_list        = ["system::default","recipe[chef-client::default]","recipe[chef-client::config]","recipe[chef-client::cron]","recipe[chef-client::delete_validation]","delivery-cluster::delivery"]
    secret_key      = "${file("${var.secret_key_file}")}"
    server_url      = "https://${var.chef_fqdn}/organizations/${var.chef_org}"
    validation_client_name = "${var.chef_org}-validator"
    validation_key  = "${file("${var.chef_org_validator}")}"
  }
  # Upload SSL certificate/key files
  provisioner "file" {
    source      = "${var.ssl_cert}"
    destination = ".delivery/certificate.pem"
  }
  provisioner "file" {
    source      = "${var.ssl_key}"
    destination = ".delivery/certificate.key"
  }
  # Replace the SSL certificate on Delivery
  provisioner "remote-exec" {
    inline = [
      "sudo mv .delivery/certificate.pem /var/opt/delivery/nginx/ca/${self.tags.Name}.crt",
      "sudo mv .delivery/certificate.key /var/opt/delivery/nginx/ca/${self.tags.Name}.key",
      "sudo chown -R delivery /etc/delivery/builder_key /etc/delivery/builder_key.pub /etc/delivery/delivery.pem",
      "sudo chmod 0600 /etc/delivery/builder_key /etc/delivery/delivery.pem",
      "sudo chmod 0640 /etc/delivery/builder_key.pub",
      "sudo delivery-ctl reconfigure",
      "sudo delivery-ctl restart nginx",
    ]
  }
  # Set permissions
  provisioner "remote-exec" {
    inline = [
      "sudo chown -R delivery:${lookup(var.ami_usermap, var.ami_os)} /etc/delivery/builder_key /etc/delivery/builder_key.pub",
      "sudo chmod 0600 /etc/delivery/builder_key /etc/delivery/${var.username}.pem",
      "sudo chmod 0644 /etc/delivery/builder_key.pub",
    ]
  }
  # Generate Delivery enterprise credentials file
  provisioner "remote-exec" {
    inline = [
      "sudo chown -R ${lookup(var.ami_usermap, var.ami_os)} .delivery",
      "sudo delivery-ctl create-enterprise ${var.ent} --ssh-pub-key-file=/etc/delivery/builder_key.pub > .delivery/${var.ent}.creds",
      "sudo chown -R ${lookup(var.ami_usermap, var.ami_os)} .delivery",
    ]
  }
  # Harvest Delivery enterprise credentials file
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.aws_private_key_file} ${lookup(var.ami_usermap, var.ami_os)}@${self.public_ip}:.delivery/${var.ent}.creds .delivery/${var.ent}.creds"
  }
  provisioner "local-exec" {
    command = <<-EOC
      echo "Delivery user: ${var.username}" | tee -a .delivery/${var.ent}.creds
      echo "Delivery user password: ${base64sha256(null_resource.delivery-user.id)} | tee -a .delivery/${var.ent}.creds
      EOC
  }
}

