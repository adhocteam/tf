###
# This includes a copy of everything provided to show how they would all be used
###

variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region  = var.region
  version = "~> 2.13.0"
}

locals {
  env         = "test"
  domain_name = "example.com"
}

module "base" {
  source = "../"

  env         = local.env
  domain_name = local.domain_name
}

module "utilities" {
  source = "../utilities"

  env         = local.env
  domain_name = local.domain_name
}

module "ingress" {
  source = "../ingress"

  env         = local.env
  domain_name = local.domain_name
}

module "static" {
  source = "../cdn_site"

  env         = local.env
  domain_name = local.domain_name
  subdomain   = "pizza"
}

module "demo" {
  source = "../plain_instance"

  base             = module.base
  application_name = "demo"
}

module "fargate" {
  source = "../fargate_cluster"

  env              = local.env
  domain_name      = local.domain_name
  application_name = "web"
  docker_image     = "nginx:latest"
}

module "postgres" {
  source = "../database"

  base        = module.base
  application = module.demo
  password    = "neverdothis"
}

module "lambda_cron" {
  source = "../lambda_cron"

  env             = local.env
  domain_name     = local.domain_name
  job_name        = "crontab"
  cron_expression = "* * ? * * *"

  env_vars = {
    "SOMETHING"      = "ANYTHING"
    "SOMETHING_ELSE" = "NOTHING"
  }

  secrets = [
    "arn:aws:secretsmanager:us-east-1:000000000000:secret:${local.env}/lambda/crontab/secret1",
    "arn:aws:secretsmanager:us-east-1:000000000000:secret:${local.env}/lambda/crontab/secret2",
  ]
}

module "production" {
  source = "../"

  env         = "prod"
  domain_name = local.domain_name
}

module "teleport_subcluster" {
  source = "../utilities/teleport_subcluster"

  env          = "prod"
  domain_name  = local.domain_name
  main_cluster = local.env
}

