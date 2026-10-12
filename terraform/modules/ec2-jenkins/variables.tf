variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_id" { type = string }
variable "instance_type" {
  type    = string
  default = "t3.medium"
}
variable "key_name" {
  type        = string
  description = "Existing EC2 key pair name for SSH access"
}
variable "allowed_ssh_cidr" {
  type        = string
  description = "Your IP in CIDR form, e.g. 1.2.3.4/32"
}
variable "instance_profile_name" {
  type        = string
  description = "IAM instance profile granting ECR + EKS access"
}
variable "tags" {
  type    = map(string)
  default = {}
}
