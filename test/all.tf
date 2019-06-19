###
# This includes a copy of everything provided to show how they would all be used
###

variable "region" {
  default = "us-east-1"
}

terraform {
  required_version = ">= 0.12"
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

  base = module.base
}

# module "ingress" {
#   source = "../ingress"

#   env         = local.env
#   domain_name = local.domain_name
# }

module "static" {
  source = "../cdn_site"

  base      = module.base
  subdomain = "pizza"
}

module "demo" {
  source = "../instance"

  base             = module.base
  application_name = "demo"
}

module "postgres" {
  source = "../database"

  base        = module.base
  application = module.demo
  password    = "neverdothis"
}

# module "fargate" {
#   source = "../fargate_cluster"

#   env              = local.env
#   domain_name      = local.domain_name
#   application_name = "web"
#   docker_image     = "nginx:latest"
# }

module "lambda_cron" {
  source = "../lambda_cron"

  base            = module.base
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

# module "production" {
#   source = "../"

#   env         = "prod"
#   domain_name = local.domain_name
# }

# module "teleport_subcluster" {
#   source = "../utilities/teleport_subcluster"

#   env          = "prod"
#   domain_name  = local.domain_name
#   main_cluster = local.env
# }

