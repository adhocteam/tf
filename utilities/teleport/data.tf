#######
### Lookup resources already created by foundation
#######

data "aws_vpc" "vpc" {
  tags {
    env = "${var.name}"
  }
}

data "aws_subnet" "application_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "app-sub-${count.index}"
    env  = "${var.name}"
  }
}

data "aws_subnet" "public_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "public-sub-${count.index}"
    env  = "${var.name}"
  }
}

data "aws_route53_zone" "external" {
  name         = "${var.domain_name}"
  private_zone = false
}

data "aws_route53_zone" "internal" {
  name         = "${var.name}.local"
  private_zone = true
}

data "aws_acm_certificate" "wildcard" {
  domain      = "${var.domain_name}"
  most_recent = true
}

data "aws_kms_key" "main" {
  key_id = "alias/${var.name}-main"
}

data "aws_secretsmanager_secret_version" "github_client_id" {
  secret_id = "${var.name}/teleport/github_client_id"
}

data "aws_secretsmanager_secret_version" "github_secret" {
  secret_id = "${var.name}/teleport/github_secret"
}

data "aws_ami" "amazon-linux-2" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}
