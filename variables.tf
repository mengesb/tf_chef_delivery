#
# AWS provider specific configs
#
variable "aws_access_key" {
  description = "Your AWS key (ex. $AWS_ACCESS_KEY_ID)"
}
variable "aws_secret_key" {
  description = "Your AWS secret (ex. $AWS_SECRET_ACCESS_KEY)"
}
variable "aws_key_name" {
  description = "Name of the key pair uploaded to AWS"
}
variable "aws_private_key_file" {
  description = "Full path to your local private key"
}
variable "aws_vpc_id" {
  description = "AWS VPC id (ex. vpc-ffffffff)"
}
variable "aws_subnet_id" {
  description = "AWS Subnet id (ex. subnet-ffffffff)"
}
variable "aws_ami_user" {
  description = "AWS AMI default username"
}
variable "aws_ami_id" {
  description = "AWS Instance ID (region dependent)"
  default = "ami-45844401"
}
variable "aws_flavor" {
  description = "AWS Instance type to deploy"
  default = "c3.xlarge"
}
variable "aws_region" {
  description = "AWS Region to deploy to"
  default = "us-west-1"
}
#
# tf_chef_delivery_server specific configs
#
variable "basename" {
  description = "Basename for AWS Name tag of CHEF Delivery server"
  default = "chef-delivery"
}
variable "count" {
  description = "Number of CHEF Delivery servers to provision. DO NOT CHANGE!"
  default = 1
}
variable "enterprise" {
  description = "Name of the CHEF Delivery enterprise to create"
  default = "Terraform"
}
variable "username" {
  description = "Username of the first CHEF Delivery user"
  default = "delivery"
}
variable "user_firstname" {
  description = "Delivery user first name on CHEF Server"
  default = "Delivery"
}
variable "user_lastname" {
  description = "Delivery user last name on CHEF Server"
  default = "User"
}
variable "user_email" {
  description = "Delivery user's e-mail address"
  default = "delivery@domain.tld"
}
variable "ssh_cidrs" {
  description = "List of CIDRs to allow SSH from"
  default = "0.0.0.0/0"
}
variable "license_file" {
  description = "Path to CHEF Delivery license file"
}
variable "chef_server_dns" {
  description = "DNS address of the CHEF Server"
}
variable "chef_org_short" {
  description = "CHEF Server organization short name (lowercase alphanumeric characters only)"
}
variable "chef_server_sg" {
  description = "CHEF Server security group id"
}
variable "secret_key_file" {
  description = "Encrypted data bag secret file"
}
