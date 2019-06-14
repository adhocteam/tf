module "vpc" {
  source = "./vpc"

  env  = var.env
  cidr = var.cidr
}

#####
# Create base resources that the other modules will look up
#####

module "encryptkey" {
  source = "./encryptkey"

  env = var.env
}

module "wildcard" {
  source = "./wildcard_cert"

  env         = var.env
  domain_name = var.domain_name
}

resource "aws_s3_bucket" "lambda_releases" {
  bucket = "${var.domain_name}-${var.env}-lambda-releases"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    env       = var.env
    terraform = "true"
    app       = "lambda-releases"
  }
}

resource "aws_security_group" "jumpbox" {
  name_prefix = "jumpbox-"
  vpc_id      = module.vpc.id

  tags = {
    env       = var.env
    terraform = "true"
    app       = "utilities"
    Name      = "jumpbox"
  }
}

