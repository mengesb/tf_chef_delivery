# Outputs
output "id" {
  value = "${aws_instance.chef-delivery.id}"
}
output "public_ip" {
  value = "${aws_instance.chef-delivery.public_ip}"
}
output "security_group_id" {
  value = "${aws_security_group.chef-delivery.id}"
}
output "chef_delivery_enterprise" {
  value = "${var.chef_delivery_enterprise}"
}
output "chef_delivery_creds" {
  value = "${file("${path.cwd}/.chef/${var.chef_delivery_enterprise}.creds")}"
}
#output "chef_delivery_build_ips" {
#  value = "${template_file.delivery_build_keys.rendered}"
#}
