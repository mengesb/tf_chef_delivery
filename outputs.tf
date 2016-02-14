# Outputs
output "id" {
  value = "${aws_instance.delivery-server.id}"
}
output "security_group_id" {
  value = "${aws_security_group.delivery-server.id}"
}
output "public_ip" {
  value = "${aws_instance.delivery-server.public_ip}"
}
output "public_dns" {
  value = "${aws_instance.delivery-server.public_dns}"
}
# In creds
#output "enterprise" {
#  value = "${var.enterprise}"
#}
output "delivery_creds" {
  value = "\n${file(".chef/${var.enterprise}.creds")}"
}
output "security_group_id" {
  value = "${aws_security_group.chef-delivery.id}"
}
output "encrypted_data_bag_secret" {
  value = "${file("${path.cwd}/.chef/encrypted_data_bag_secret")}"
}
