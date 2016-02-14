## Outputs
output "delivery_creds" {
  value = "\n${file(".chef/${var.enterprise}.creds")}"
}
output "delivery_sg" {
  value = "${aws_security_group.chef-delivery.id}"
}
output "encrypted_data_bag_secret" {
  value = "${file("${path.cwd}/.chef/encrypted_data_bag_secret")}"
}
