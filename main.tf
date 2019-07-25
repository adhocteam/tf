terraform {
  required_version = ">= 0.12"
}

resource "aws_ebs_encryption_by_default" "on" {
  enabled = true
}

module "vpc" {
  source = "./vpc"

  env  = var.env
  cidr = var.cidr_block
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
  primary     = var.primary
}

module "ingress" {
  source = "./ingress"

  env         = var.env
  domain_name = var.domain_name
  public      = var.public_ingress
  cidr_block  = var.cidr_block
  vpc_id      = module.vpc.id
  subnet_ids = {
    application = module.vpc.application[*].id
    public      = module.vpc.public[*].id
  }
  internal_dns = module.vpc.internal_dns
  external_dns = data.aws_route53_zone.external
  wildcard_arn = module.wildcard.arn
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

