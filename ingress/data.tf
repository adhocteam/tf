#######
### Lookup resources already created by foundation
#######
data "aws_caller_identity" "current" {
}

data "aws_vpc" "vpc" {
  tags = {
    env = var.env
  }
}

data "aws_subnet" "application" {
  count  = 3
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    name = "app-sub-${count.index}"
    env  = var.env
  }
}

data "aws_subnet" "public" {
  count  = 3
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    name = "public-sub-${count.index}"
    env  = var.env
  }
}

data "aws_route53_zone" "external" {
  name         = var.domain_name
  private_zone = false
}

data "aws_route53_zone" "internal" {
  name         = "${var.env}.local"
  private_zone = true
}

data "aws_acm_certificate" "wildcard" {
  domain      = var.domain_name
  most_recent = true
}

data "aws_kms_alias" "main" {
  name = "alias/${var.env}-main"
}

data "aws_security_group" "jumpbox" {
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    env  = var.env
    app  = "utilities"
    Name = "jumpbox"
  }
}

data "aws_ami" "base" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["adhoc_base*"]
  }
}

