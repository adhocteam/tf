#######
# Teleport (https://gravitational.com/teleport/docs/intro/)
# provides SSH bastion services to connect to rest of infrastructure
#######

# Public DNS name for client use to connect to proxies
resource "aws_route53_record" "public" {
  zone_id = "${data.aws_route53_zone.external.id}"
  name    = "teleport.${var.env}"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_elb.proxy.dns_name}"]
}

module "cert" {
  source      = "../../wildcard_cert"
  env         = "${var.env}"
  root_domain = "${var.domain_name}"

  # Can't use aws_route53_record.public.fqdn here to prevent cycle with ELB
  domain = "teleport.${var.env}.${var.domain_name}"
}

# Private DNS name inside VPC for auth nodes as light-weight service discovery
resource "aws_route53_zone" "teleport" {
  name    = "teleport.local"
  vpc_id  = "${data.aws_vpc.vpc.id}"
  comment = "${var.env} Teleport internal DNS"

  tags {
    env       = "${var.env}"
    terraform = "true"
    Name      = "teleport-dns"
  }
}

resource "aws_route53_record" "auth_internal" {
  zone_id = "${aws_route53_zone.teleport.id}"
  name    = "auth"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_lb.auth.dns_name}"]
}

# A create a random cluster token at creation time. No rotation as of now.
resource "random_string" "cluster_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret_version" "cluster_token" {
  secret_id     = "${var.env}/teleport/cluster_token"
  secret_string = "${random_string.cluster_token.result}"
}

resource "aws_iam_policy" "teleport_secrets" {
  name        = "temp-teleport-secrets"
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
            "Action": [
              "kms:Encrypt",
              "kms:Decrypt"
            ],
            "Resource": [
              "${data.aws_kms_alias.main.arn}"
          ]
        }
    ]
}
EOF
}
