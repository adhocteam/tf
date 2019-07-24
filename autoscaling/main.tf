terraform {
  required_version = ">= 0.12"
}

locals {
  ami_id = length(var.ami_id) == 0 ? var.base.ami.id : var.ami_id
}

#####
# Autoscaling configuration
#####

resource "aws_autoscaling_group" "application" {
  name_prefix         = "${aws_launch_template.application.id}-${aws_launch_template.application.latest_version}"
  vpc_zone_identifier = var.base.vpc.application[*].id

  max_size         = var.max_count
  min_size         = 0
  desired_capacity = var.desired_count
  force_delete     = false

  target_group_arns         = coalescelist(var.target_group_arns, aws_alb_target_group.application[*].arn)
  health_check_grace_period = 300
  health_check_type         = "ELB"
  wait_for_elb_capacity     = var.desired_count
  wait_for_capacity_timeout = "600s"

  lifecycle {
    create_before_destroy = true
  }

  launch_template {
    id      = aws_launch_template.application.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.base.env}-${var.application_name}"
    propagate_at_launch = true
  }
  tag {
    key                 = "terraform"
    value               = "true"
    propagate_at_launch = true
  }
  tag {
    key                 = "environment"
    value               = var.base.env
    propagate_at_launch = true
  }
  tag {
    key                 = "app"
    value               = var.application_name
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.base.env}-${var.application_name}-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.application.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 60
  }
}

resource "aws_autoscaling_policy" "memory" {
  name                   = "${var.base.env}-${var.application_name}-memory-policy"
  autoscaling_group_name = aws_autoscaling_group.application.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageMemoryUtilization"
    }

    target_value = 60
  }
}

resource "aws_launch_template" "application" {
  name_prefix                          = "${var.base.env}-${var.application_name}-"
  disable_api_termination              = false
  image_id                             = local.ami_id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_size
  ebs_optimized                        = true

  key_name = var.base.ssh_key
  vpc_security_group_ids = [
    var.base.security_groups["teleport_nodes"].id,
    var.base.security_groups["jumpbox_nodes"].id,
    aws_security_group.app.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.iam.name
  }

  user_data = var.user_data != "" ? var.user_data : null

  credit_specification {
    cpu_credits = "unlimited"
  }

  block_device_mappings {
    ebs {
      volume_type           = "gp2"
      volume_size           = var.volume_size
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.base.env}-${var.application_name}-"
      "terraform" = "true"
      "env"       = var.base.env
      "app"       = var.application_name
    }
  }

  tags = {
    Name      = "${var.base.env}-${var.application_name}-launch-template"
    terraform = "true"
    env       = var.base.env
    app       = var.application_name
  }
}

#######
# Security group for application
#######

resource "aws_security_group" "app" {
  name_prefix = "${var.application_name}-app-"
  vpc_id      = var.base.vpc.id

  tags = {
    app       = var.application_name
    terraform = "true"
    env       = var.base.env
  }
}

# Allow all outbound, e.g. third-pary API endpoints, by default
resource "aws_security_group_rule" "egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.app.id
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
  role = aws_iam_role.iam.name
  policy_arn = "arn:aws:iam::${var.base.account.account_id}:policy/${var.base.env}/teleport/${var.base.env}-instance-teleport-secrets"
}
