## Outputs
output "delivery_creds" {
  value = "\n${file(".chef/${var.enterprise}.creds")}"
}
output "security_group_id" {
  value = "${aws_security_group.chef-delivery.id}"
}
output "encrypted_data_bag_secret" {
  value = "${file("${path.cwd}/.chef/encrypted_data_bag_secret")}"
}
