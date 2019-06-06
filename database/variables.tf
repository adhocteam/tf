variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "application_name" {
  description = "the name of the application that will access this database"
  default     = "demo"
}

variable "app_sg" {
  description = "the security group of the application that needs access to the database, probably from the module outputs"
}

variable "user" {
  default = "dbuser"
}

variable "password" {
}

