variable "base" {
  description = "object with the outputs of the base module"
}

variable "application" {
  description = "an object describing the application to allow access to this database"
}

variable "db_user" {
  type        = string
  description = "OPTIONAL: the username for the Postgres user"
  default     = "dbuser"
}

# variable "password" {
#   type        = string
#   description = "the password for the Postgres user. NOTE: will be stored in Terraform state"
# }

variable "instance_class" {
  type        = string
  description = "OPTIONAL: the instance class for the db."
  default     = "db.t2.small"
}

