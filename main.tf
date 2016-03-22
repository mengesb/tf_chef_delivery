# Chef Delivery AWS security group - https://github.com/Chef-cookbooks/delivery-cluster
resource "aws_security_group" "chef-delivery" {
  name        = "${var.hostname}.${var.domain} security group"
  description = "Delivery server ${var.hostname}.${var.domain}"
  vpc_id      = "${var.aws_vpc_id}"
  tags        = {
    Name      = "${var.hostname}.${var.domain} security group"
  }
}
# Chef Server -> Delivery
resource "aws_security_group_rule" "chef-delivery_allow_all_Chef-server" {
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  source_security_group_id = "${var.chef_sg}"
  security_group_id = "${aws_security_group.chef-delivery.id}"
}
# Delivery -> Chef Server
resource "aws_security_group_rule" "chef-server_allow_all_chef-delivery" {
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  source_security_group_id = "${aws_security_group.chef-delivery.id}"
  security_group_id = "${var.chef_sg}"
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
#
# Chef Delivery requirements
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
resource "template_file" "builder-json" {
  template = "${file("${path.module}/files/delivery-builder-keys-json.tpl")}"
}
resource "template_file" "delivery-json" {
  template = "${file("${path.module}/files/delivery-json.tpl")}"
}
resource "null_resource" "clean-slate" {
  provisioner "local-exec" {
    command = "rm -rf .delivery ; mkdir -p .delivery"
  }
}
resource "null_resource" "delivery-user" {
  depends_on = ["null_resource.clean-slate"]
  connection {
    user        = "${lookup(var.ami_usermap, var.ami_os)}"
    private_key = "${var.aws_private_key_file}"
    host        = "${var.chef_fqdn}"
  }
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
  provisioner "local-exec" {
    command = "scp -o stricthostkeychecking=no -i ${var.aws_private_key_file} ${lookup(var.ami_usermap, var.ami_os)}@${var.chef_fqdn}:.delivery/${var.username}.pem .delivery/${var.username}.pem"
  }
  provisioner "local-exec" {
    command = <<EOC
cat .delivery/${var.username}.pem | perl -pe 's/\n/\\n/g' > .delivery/${var.username}_databag
cat > .delivery/delivery.json <<EOF
${template_file.delivery-json.rendered}
EOF
cd .delivery && perl -pe 's/text2/`cat ${var.username}_databag`/ge' -i delivery.json
EOC
  }
}
resource "null_resource" "delivery-server" {
  depends_on = ["null_resource.clean-slate"]
  provisioner "local-exec" {
    command = "knife node-delete ${var.hostname}.${var.domain} -y ; echo OK"
  }
  provisioner "local-exec" {
    command = "knife client-delete ${var.hostname}.${var.domain} -y ; echo OK"
  }
}
resource "null_resource" "builder-key" {
  depends_on = ["null_resource.clean-slate"]
  provisioner "local-exec" {
    command = "ssh-keygen -q -t rsa -N '' -b 2048 -f .delivery/builder_key"
  }
  provisioner "local-exec" {
    command = <<EOC
cat .delivery/builder_key | perl -pe 's/\n/\\n/g' > .delivery/builder_databag
cat > .delivery/delivery_builder_keys.json <<EOF
${template_file.builder-json.rendered}
EOF
cd .delivery && perl -pe 's/text1/`cat builder_databag`/ge' -i delivery_builder_keys.json
EOC
  }
}
resource "null_resource" "delivery-cookbooks" {
  depends_on = ["null_resource.clean-slate"]
  connection {
    user        = "${lookup(var.ami_usermap, var.ami_os)}"
    private_key = "${var.aws_private_key_file}"
    host        = "${var.chef_fqdn}"
  }
  provisioner "file" {
    source      = "${path.module}/files/chef-cookbooks.sh"
    destination = "chef-cookbooks.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "bash chef-cookbooks.sh ; rm -rf chef-cookbooks.sh",
    ]
  }
}
#
# Chef Delivery
#
resource "aws_instance" "chef-delivery" {
  depends_on    = ["null_resource.builder-key","null_resource.delivery-user","null_resource.delivery-server","null_resource.delivery-cookbooks"]
  ami           = "${lookup(var.ami_map, format("%s-%s", var.ami_os, var.aws_region))}"
  count         = "${var.server_count}"
  instance_type = "${var.aws_flavor}"
  subnet_id     = "${var.aws_subnet_id}"
  vpc_security_group_ids = ["${aws_security_group.chef-delivery.id}"]
  key_name      = "${var.aws_key_name}"
  tags = {
    Name        = "${var.hostname}.${var.domain}"
  }
  root_block_device = {
    delete_on_termination = true
  }
  connection {
    user        = "${lookup(var.ami_usermap, var.ami_os)}"
    private_key = "${var.aws_private_key_file}"
    host        = "${self.public_ip}"
  }
  # Create path to delivery license
  provisioner "remote-exec" {
    inline = [
      "mkdir -p .delivery",
      "sudo mkdir -p /var/opt/delivery/license /etc/delivery /etc/chef"
    ]
  }
  # Copy over Delivery user PEM
  provisioner "file" {
    source      = ".delivery/${var.username}.pem"
    destination = ".delivery/${var.username}.pem"
  }
  # Copy in license file
  provisioner "file" {
    source      = "${var.delivery_license}"
    destination = ".delivery/delivery.license"
  }
  # Copy in builder key pair
  provisioner "file" {
    source      = ".delivery/builder_key"
    destination = ".delivery/builder_key"
  }
  provisioner "file" {
    source      = ".delivery/builder_key.pub"
    destination = ".delivery/builder_key.pub"
  }
  # Put files in proper locations
  provisioner "remote-exec" {
    inline = [
      "sudo mv .delivery/delivery.license /var/opt/delivery/license",
      "sudo mv .delivery/* /etc/delivery",
      "sudo chown -R delivery /etc/delivery/builder_key /etc/delivery/builder_key.pub",
      "sudo chown -R root:root /var/opt/delivery/license /etc/delivery /etc/chef"
    ]
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
  # Provision with Chef
  provisioner "chef" {
    attributes_json = "${template_file.attributes-json.rendered}"
    # environment     = "_default"
    run_list        = ["system::default","delivery-cluster::delivery"]
    node_name       = "${var.hostname}.${var.domain}"
    secret_key      = "${file("${var.secret_key_file}")}"
    server_url      = "https://${var.chef_fqdn}/organizations/${var.chef_org}"
    validation_client_name = "${var.chef_org}-validator"
    validation_key  = "${file("${var.chef_org_validator}")}"
  }
  # Place SSL certificate/key files
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
      "sudo delivery-ctl reconfigure",
      "sudo delivery-ctl restart nginx",
    ]
  }
  # Set permissions and file placement
  provisioner "remote-exec" {
    inline = [
      "sudo chown -R delivery:${lookup(var.ami_usermap, var.ami_os)} /etc/delivery/builder_key /etc/delivery/builder_key.pub",
      "sudo chmod 0600 /etc/delivery/builder_key /etc/delivery/${var.username}.pem",
      "sudo chmod 0644 /etc/delivery/builder_key.pub",
    ]
  }
  # Generate Chef Delivery enterprise credentials file
  provisioner "remote-exec" {
    inline = [
      "sudo chown -R ${lookup(var.ami_usermap, var.ami_os)} .delivery",
      "sudo delivery-ctl create-enterprise ${var.ent} --ssh-pub-key-file=/etc/delivery/builder_key.pub > .delivery/${var.ent}.creds",
      "sudo chown -R ${lookup(var.ami_usermap, var.ami_os)} .delivery",
    ]
  }
  # Copy back Chef Delivery enterprise credentials file
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.aws_private_key_file} ${lookup(var.ami_usermap, var.ami_os)}@${self.public_ip}:.delivery/${var.ent}.creds .delivery/${var.ent}.creds"
  }
  # Local echo
  provisioner "local-exec" {
    command = "cat .delivery/${var.ent}.creds"
  }
}
# Public Route53 DNS record
resource "aws_route53_record" "chef-delivery" {
  zone_id = "${var.r53_zone_id}"
  name    = "${aws_instance.chef-delivery.tags.Name}"
  type    = "A"
  ttl     = "${var.r53_ttl}"
  records = ["${aws_instance.chef-delivery.public_ip}"]
}
