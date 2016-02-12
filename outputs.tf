## Outputs
output "chef_delivery_sg" {
  value = "${aws_security_group.chef-delivery.id}"
}
output "chef_delivery_url" {
  value = "https://${aws_instance.chef-delivery.public_dns}/e/${var.enterprise}"
}
output "chef_delivery_creds" {
  value = "${file(".chef/${var.enterprise}.creds")}"
}
