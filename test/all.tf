###
# This includes a copy of everything provided to show how they would all be used
###

variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region  = "${var.region}"
  version = ">= 1.20.0"
}

locals {
  env         = "test"
  domain_name = "example.com"
}

module "base" {
  source = "../"

  env         = "${local.env}"
  domain_name = "${local.domain_name}"
}

module "static" {
  source = "../static_site"

  env         = "${local.env}"
  domain_name = "${local.domain_name}"
  subdomain   = "pizza"
}

module "demo" {
  source = "../plain_instance"

  env              = "${local.env}"
  domain_name      = "${local.domain_name}"
  application_name = "demo"
}

module "fargate" {
  source = "../fargate_cluster"

  env              = "${local.env}"
  domain_name      = "${local.domain_name}"
  application_name = "web"
  docker_image     = "nginx:latest"
}

variable "db_password" {
  description = "Normally this would be left blank"
  default     = "neverdothis"
}

module "postgres" {
  source = "../database"

  env              = "${local.env}"
  application_name = "demo"
  app_sg           = "${module.demo.app_sg_id}"
  password         = "{$var.db_password}"
}
