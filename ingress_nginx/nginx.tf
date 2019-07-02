#######
# Nginx Reverse Proxy to send data to our backends
#######

# Create ECR repo for docker image and provide cross account access if needed
resource "aws_ecr_repository" "nginx" {
  count = local.enabled
  name  = "ingress-${var.base.env}"
}

resource "aws_ecr_repository_policy" "cross_account_access" {
  count      = length(local.enabled * var.other_accounts)
  repository = aws_ecr_repository.nginx.name

  policy = local.cross_account_policy

}

data "aws_iam_policy_document" "cross_account_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.other_accounts
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cross_account_assume_role" {
  count              = local.enabled
  name               = "ingress-cross-account-${var.base.env}"
  assume_role_policy = data.aws_iam_policy_document.cross_account_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cross_account_assume_role" {
  count      = local.enabled
  role       = aws_iam_role.cross_account_assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Create an auto-scaling group for nginx because fargate does not yet support multiple target groups
docker_image = "${aws_ecr_repository.nginx.repository_url}:latest"
#,, Create the hosts for nginx
resource "aws_instance" "nginx" {
  count         = 1
  ami           = var.base.ami.id
  instance_type = "t3.medium"

  iam_instance_profile = aws_iam_instance_profile.iam.name

  #user_data = <<EOF
  ##!/usr/bin/env bash
  #set -euo pipefail

  #eval $(aws ecr get-login --region=us-east-1 --no-include-email)

  #docker pull ${aws_ecr_repository.nginx.repository_url}:latest
  #docker run -d --restart=unless-stopped \
  #--name nginx \
  #-p 80:80 \
  #-p 200:200 \
  #-p 443:443 \
  #${aws_ecr_repository.nginx.repository_url}:latest

  #EOF
}


#TODO(bob) this may be able to be restricted to our private CIDR b/c we use proxy_protocol
resource "aws_security_group_rule" "nginx_http" {
  type        = "ingress"
  from_port   = "80"
  to_port     = "80"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.nginx.id
}

resource "aws_security_group_rule" "nginx_https" {
  type        = "ingress"
  from_port   = "443"
  to_port     = "443"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.nginx.id
}

resource "aws_security_group_rule" "nginx_healthcheck" {
  type        = "ingress"
  from_port   = "200"
  to_port     = "200"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.nginx.id
}

resource "aws_security_group_rule" "nginx_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.nginx.id
}

resource "aws_alb_target_group_attachment" "nginx" {
  count            = local.enabled
  target_group_arn = local.nlb_target_groups[count.index].arn
  target_id        = aws_instance.box[count.index].private_ip
}

locals {
  cross_account_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.other_accounts[count.index]}:root"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories"
      ]
    }
  ]
}
EOF

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}
