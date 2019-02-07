#######
# Teleport (https://gravitational.com/teleport/docs/intro/)
# provides SSH bastion services to connect to rest of infrastructure
#
# This uses the 'trusted cluster' mechanism to create a "subcluster"
# only accessible via the main cluster. Intended use case is for higher
# environments where you do not want to have a public endpoint open.
#######

# Private DNS name inside VPC for auth nodes as light-weight service discovery
resource "aws_route53_zone" "teleport" {
  name    = "teleport.local"
  comment = "${var.env} Teleport internal DNS"

  vpc {
    vpc_id = "${data.aws_vpc.vpc.id}"
  }

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
# The secret must exist prior to running this but the value will be overwritten
resource "random_string" "cluster_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret_version" "cluster_token" {
  secret_id     = "${var.env}/teleport/cluster_token"
  secret_string = "${random_string.cluster_token.result}"
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
            "Resource": "${data.aws_kms_alias.main.target_key_arn}"
        }
    ]
}
EOF
}
