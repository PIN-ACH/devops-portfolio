variable "cluster_name" { type = string }
variable "cluster_version" {
  type    = string
  default = "1.30"
}
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "desired_size" {
  type    = number
  default = 2
}
variable "min_size" {
  type    = number
  default = 1
}
variable "max_size" {
  type    = number
  default = 3
}
variable "capacity_type" {
  type    = string
  default = "SPOT" # Cheaper for a demo; set to ON_DEMAND for stability.
}
variable "tags" {
  type    = map(string)
  default = {}
}
