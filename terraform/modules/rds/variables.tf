variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "db_name" {
  type    = string
  default = "appdb"
}
variable "db_username" {
  type    = string
  default = "appuser"
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro" # Free-tier-ish; cheapest usable class.
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "allowed_security_group_ids" {
  type        = list(string)
  description = "SGs permitted to reach the DB (EKS nodes, Jenkins)"
}
variable "tags" {
  type    = map(string)
  default = {}
}
