variable "region" {
  type    = string
  default = "us-east-1"
}
variable "project" {
  type    = string
  default = "devops-portfolio"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "cluster_version" {
  type    = string
  default = "1.30"
}
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "node_capacity_type" {
  type    = string
  default = "SPOT"
}
variable "node_desired_size" {
  type    = number
  default = 2
}
variable "node_min_size" {
  type    = number
  default = 1
}
variable "node_max_size" {
  type    = number
  default = 3
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "jenkins_instance_type" {
  type    = string
  default = "t3.medium"
}
variable "key_name" {
  type        = string
  description = "Existing EC2 key pair for SSH into Jenkins"
}
variable "allowed_ssh_cidr" {
  type        = string
  description = "Your public IP in CIDR notation, e.g. 203.0.113.4/32"
}
