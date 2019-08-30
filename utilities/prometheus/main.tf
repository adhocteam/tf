terraform {
  required_version = ">= 0.12"
}

#####
# Provides a single prometheus instance to scrape. Prometheus is stateful
# and holds the data on disk, so we don't want it to autoscale. The ASG 
# is used to boot up a new copy automatically on failure.
#####

resource "aws_autoscaling_group" "prometheus" {
  name_prefix         = "${var.base.env}-prometheus-"
  vpc_zone_identifier = var.base.vpc.application[*].id

  max_size         = 1
  min_size         = 1
  desired_capacity = 1
  force_delete     = false

  target_group_arns         = aws_alb_target_group.application[*].arn
  health_check_grace_period = 300
  health_check_type         = "ELB"
  wait_for_elb_capacity     = 1
  wait_for_capacity_timeout = "600s"

  lifecycle {
    ignore_changes        = [desired_capacity, ami]
    create_before_destroy = true
  }

  launch_template {
    id      = aws_launch_template.prometheus.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.base.env}-prometheus"
    propagate_at_launch = true
  }
  tag {
    key                 = "terraform"
    value               = "true"
    propagate_at_launch = true
  }
  tag {
    key                 = "env"
    value               = var.base.env
    propagate_at_launch = true
  }
  tag {
    key                 = "app"
    value               = "prometheus"
    propagate_at_launch = true
  }
}

locals {
  default = templatefile("${path.module}/prometheus.tmpl", {
    env = var.base.env
  })
  custom    = <<-EOF
  #!/usr/bin/env bash
  docker run -d --restart always \
      -p 9090:9090 \
      --name prometheus \
      ${var.prometheus_image}
  EOF
  user_data = var.prometheus_image != "" ? local.custom : local.default
}

resource "aws_launch_template" "prometheus" {
  name_prefix                          = "${var.base.env}-prometheus-"
  disable_api_termination              = false
  image_id                             = var.base.ami.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_size
  ebs_optimized                        = true

  key_name = var.base.ssh_key
  vpc_security_group_ids = [
    var.base.security_groups["teleport_nodes"].id,
    var.base.security_groups["jumpbox_nodes"].id,
    var.base.security_groups["node_exporter"].id,
    var.base.security_groups["prometheus"].id,
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.iam.name
  }

  user_data = var.user_data != "" ? base64encode(var.user_data) : null

  credit_specification {
    cpu_credits = "unlimited"
  }

  monitoring {
    enabled = true
  }

  tags = {
    Name      = "${var.base.env}-prometheus-launch-template"
    terraform = "true"
    env       = var.base.env
    app       = "prometheus"
  }
}

#####
# Base IAM instance profile
#####
resource "aws_iam_instance_profile" "iam" {
  name = "${var.base.env}-asg-${var.application_name}"
  role = aws_iam_role.iam.name
}

# Auth instance profile and roles
resource "aws_iam_role" "iam" {
  name = "${var.base.env}-asg-${var.application_name}"

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

# Give it base teleport permissions
resource "aws_iam_role_policy_attachment" "iam_teleport" {
  role       = aws_iam_role.iam.name
  policy_arn = "arn:aws:iam::${var.base.account.account_id}:policy/${var.base.env}/teleport/${var.base.env}-instance-teleport-secrets"
}

# Give it the ability to query EC2 nodes for sevice discovery
resource "aws_iam_role_policy_attachment" "ec2_readonly" {
  role       = aws_iam_role.iam.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}
