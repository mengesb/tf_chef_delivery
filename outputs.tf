# Outputs
output "delivery_creds" {
  value = "\n${file(".chef/${var.enterprise}.creds")}"
}
output "public_dns" {
  value = "${aws_instance.chef-delivery.public_dns}"
}
output "security_group_id" {
  value = "${aws_security_group.chef-delivery.id}"
}
