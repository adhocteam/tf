#######
### Lookup resources already created by foundation
#######

data "aws_region" "current" {}

data "aws_vpc" "vpc" {
  tags {
    env = "${var.env}"
  }
}

data "aws_subnet" "application_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "app-sub-${count.index}"
    env  = "${var.env}"
  }
}

data "aws_subnet" "public_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "public-sub-${count.index}"
    env  = "${var.env}"
  }
}

data "aws_route53_zone" "external" {
  name         = "${var.domain_name}"
  private_zone = false
}

data "aws_kms_key" "main" {
  key_id = "alias/${var.env}-main"
}

data "aws_secretsmanager_secret_version" "github_client_id" {
  secret_id = "${var.env}/teleport/github_client_id"
}

data "aws_secretsmanager_secret_version" "github_secret" {
  secret_id = "${var.env}/teleport/github_secret"
}

data "aws_ami" "base" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["adhoc_base*"]
  }
}
