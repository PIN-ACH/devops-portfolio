variable "name" { type = string }
variable "ecr_repository_arn" { type = string }
variable "db_secret_arn" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
