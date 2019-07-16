terraform {
  required_version = ">= 0.12"
}

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

module "ingress" {
  source = "./ingress"

  env          = var.env
  domain_name  = var.domain_name
  public       = var.public_ingress
  external_dns = data.aws_route53_zone.external
  vpc          = module.vpc
  wildcard     = module.wildcard
}

#####
# Singleton resources referenced by child modules
####

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

# A create a random cluster token at creation time. No rotation as of now.
resource "random_string" "cluster_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret_version" "cluster_token" {
  secret_id     = "${var.env}/teleport/cluster_token"
  secret_string = random_string.cluster_token.result
}

### Shared IAM role for instances running teleport
resource "aws_iam_policy" "teleport_secrets" {
  name        = "${var.env}-instance-teleport-secrets"
  path        = "/${var.env}/teleport/"
  description = "Allows nodes to run local teleport daemon"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect" : "Allow",
            "Action" : "ec2:DescribeTags",
            "Resource" : "*"
        },
        {
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "${data.aws_secretsmanager_secret.cluster_token.arn}"
        },
        {
            "Effect": "Allow",
            "Action": "kms:Decrypt",
            "Resource": "${module.encryptkey.arn}"
        }
    ]
}
EOF

}

