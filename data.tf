data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_route53_zone" "external" {
  name         = var.domain_name
  private_zone = false
}

data "aws_ami" "base" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["adhoc_base*"]
  }
}

data "aws_secretsmanager_secret" "cluster_token" {
  name = "${var.env}/teleport/cluster_token"
}
