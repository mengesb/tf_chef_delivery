# Outputs
output "credentials" {
  value = "\n${file(".delivery/${var.ent}.creds")}"
}
output "fqdn" {
  value = "${aws_instance.chef-delivery.tags.Name}"
}
output "security_group_id" {
  value = "${aws_security_group.chef-delivery.id}"
}
