module "vpc" {
  source = "./vpc"

  env  = "${var.env}"
  cidr = "${var.cidr}"
}

module "encryptkey" {
  source = "./encryptkey"

  env = "${var.env}"
}

module "wildcard" {
  source = "./wildcard_cert"

  env         = "${var.env}"
  root_domain = "${var.domain_name}"
  domain      = "${var.domain_name}"
}

resource "aws_s3_bucket" "lambda_releases" {
  bucket = "${var.domain_name}-${var.env}-lambda-releases"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags {
    env         = "${var.env}"
    domain_name = "${var.domain_name}"
    terraform   = "True"
    app         = "lambda-releases"
  }
}
