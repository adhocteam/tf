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

module "dev" {
  source = "../"

  env         = local.env
  domain_name = local.domain_name
}

module "utilities" {
  source = "../utilities"

  base = module.dev
}


module "static" {
  source = "../cdn_site"

  base      = module.dev
  subdomain = "pizza"
}

module "demo" {
  source = "../instance"

  base             = module.dev
  application_name = "demo"
}

module "postgres" {
  source = "../database"

  base        = module.dev
  application = module.demo
  password    = "neverdothis"
}

module "fargate" {
  source = "../fargate_cluster"

  base             = module.dev
  application_name = "web"
  docker_image     = "nginx:latest"
  environment_variables = [
    {
      "name"  = "DB_USER"
      "value" = "something"
    },
    {
      "name"  = "ENVIRONMENT"
      "value" = "development"
    },
  ]
  secrets = [
    {
      "name"      = "DB_PASSWORD"
      "valueFrom" = "arn:aws:secretsmanager:region:${var.region}::secret:dev/db_password-v4GYs6"
    },
    {
      "name"      = "API_KEY"
      "valueFrom" = "arn:aws:secretsmanager:region:${var.region}::secret:dev/api_key-v4GYs7"
    },
  ]
}

module "console" {
  source = "../command_console"

  base            = module.dev
  fargate_cluster = module.fargate
}

module "demo_asg" {
  source = "../autoscaling"

  base             = module.dev
  application_name = "asg"
}

module "ingress" {
  source = "../ingress"

  base = module.dev
  applications = [
    module.demo,
    module.fargate,
    module.demo_asg
  ]
}

module "lambda_cron" {

  source = "../lambda_cron"

  base            = module.dev
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

module "nginx_ingress" {
  source = "../ingress"

  base         = module.production
  nginx        = true
  applications = []
}

# module "teleport_subcluster" {
#   source = "../utilities/teleport_subcluster"

#   env          = "prod"
#   domain_name  = local.domain_name
#   main_cluster = local.env
# }

