# Outputs
output "id" {
  value = "${aws_instance.chef-delivery.id}"
}
output "security_group_id" {
  value = "${aws_security_group.chef-delivery.id}"
}
output "public_ip" {
  value = "${aws_instance.chef-delivery.public_ip}"
}
output "public_dns" {
  value = "${aws_instance.chef-delivery.public_dns}"
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
