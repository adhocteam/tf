terraform {
  required_version = ">= 0.12"
}

locals {
  handler = coalesce(var.handler, var.job_name)
}

resource "aws_lambda_function" "job" {
  function_name = var.job_name
  description   = "Terraform-managed cron job for ${var.job_name} that invokes ${local.handler}"

  s3_bucket = var.base.lambda_releases.id
  s3_key    = "${var.job_name}.zip"

  handler = local.handler
  runtime = var.runtime

  // Allow to run up to 5 minutes. Max is 15 minutes
  timeout     = 600
  memory_size = var.memory_size

  role = aws_iam_role.job.arn

  dynamic "environment" {
    for_each = length(var.env_vars) ? [var.env_vars] : []
    content {
      variables = environment.value
    }
  }

  // Encrypts any environment variables
  kms_key_arn = var.base.key.arn

  vpc_config {
    subnet_ids         = var.base.vpc.application[*].id
    security_group_ids = [aws_security_group.job.id]
  }

  tags = {
    terraform = "true"
    app       = var.job_name
    handler   = local.handler
    type      = "cron"
  }
}

#####
# Default security group for lambda function
#####
resource "aws_security_group" "job" {
  name_prefix = "${var.job_name}-"
  vpc_id      = var.base.vpc.id

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = var.job_name
    name      = "cron-${var.job_name}"
  }
}

// Block all inbound
resource "aws_security_group_rule" "ingress" {
  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = -1
  self      = true

  security_group_id = aws_security_group.job.id
}

// Allow all outbound by default
resource "aws_security_group_rule" "lb_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = -1
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.job.id
}

######
# Cron job setup
######
resource "aws_cloudwatch_event_rule" "crontab" {
  name                = "crontab-${var.base.env}-${var.job_name}"
  description         = "Terraform-managed crontab for firing ${var.job_name}"
  schedule_expression = "cron(${var.cron_expression})"
}

resource "aws_cloudwatch_event_target" "crontab" {
  target_id = "${var.base.env}-${var.job_name}-sync_lambda_target"
  rule      = aws_cloudwatch_event_rule.crontab.name
  arn       = aws_lambda_function.job.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_crontab" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.crontab.arn
}

#####
# IAM role which dictates what other AWS services the Lambda function
# may access.
#####

resource "aws_iam_role" "job" {
  name = "cronjob-${var.base.env}-${var.job_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

# Helper for allowing access to securely stored secrets
# The helper uses the main shared key, provide your own by attaching to the output
# role if you have a more restricted key used in Secrets Manager
resource "aws_iam_role_policy_attachment" "basic_exec_role" {
  role       = aws_iam_role.job.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.job.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "secrets" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = var.secrets
  }
}

resource "aws_iam_policy" "secrets" {
  name   = "${var.base.env}-${var.job_name}-secrets"
  path   = "/${var.base.env}/${var.job_name}/"
  policy = data.aws_iam_policy_document.secrets.json
}

resource "aws_iam_role_policy_attachment" "secrets" {
  role       = aws_iam_role.job.name
  policy_arn = aws_iam_policy.secrets.arn
}

# Use of the shared KMS key for secrets decryption
resource "aws_iam_policy" "shared_key_access" {
  name        = "${var.base.env}-${var.job_name}-key-access"
  path        = "/${var.base.env}/${var.job_name}/"
  description = "Allows function to use main KMS key for environment"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "kms:Decrypt",
            "Resource": "${var.base.key.arn}"
        }
    ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "shared_key_access" {
  role       = aws_iam_role.job.name
  policy_arn = aws_iam_policy.shared_key_access.arn
}
