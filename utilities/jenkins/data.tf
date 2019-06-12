data "aws_vpc" "vpc" {
  tags = {
    env = var.env
  }
}

data "aws_subnet" "application_subnet" {
  count  = 3
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    name = "app-sub-${count.index}"
    env  = var.env
  }
}

data "aws_subnet" "public_subnet" {
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

data "aws_secretsmanager_secret" "cluster_token" {
  name = "${var.env}/teleport/cluster_token"
}

data "aws_secretsmanager_secret_version" "github_client_id" {
  secret_id = "${var.env}/jenkins/github_client_id"
}

data "aws_secretsmanager_secret_version" "github_client_secret" {
  secret_id = "${var.env}/jenkins/github_client_secret"
}

data "aws_secretsmanager_secret_version" "github_password" {
  secret_id = "${var.env}/jenkins/github_password"
}

data "aws_secretsmanager_secret_version" "slack_token" {
  secret_id = "${var.env}/jenkins/slack_token"
}

data "aws_secretsmanager_secret_version" "docker_password" {
  secret_id = "${var.env}/jenkins/docker_password"
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

