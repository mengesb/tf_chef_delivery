## Outputs
output "chef_delivery_creds" {
  value = "${file(".chef/${var.enterprise}.creds")}"
}
output "chef_delivery_sg" {
  value = "${aws_security_group.chef-delivery.id}"
}
