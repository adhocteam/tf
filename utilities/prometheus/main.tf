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
    value               = var.application_name
    propagate_at_launch = true
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

  user_data = var.user_data != "" ? base64encode(var.user_data) : null

  credit_specification {
    cpu_credits = "unlimited"
  }

  monitoring {
    enabled = true
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
  role       = aws_iam_role.iam.name
  policy_arn = "arn:aws:iam::${var.base.account.account_id}:policy/${var.base.env}/teleport/${var.base.env}-instance-teleport-secrets"
}
module "prometheus" {
  source = "../../autoscaling"

  base              = var.base
  application_name  = "prometheus"
  application_ports = [9090]
  public            = false
  max_count         = 1
  desired_count     = 1
  user_data         = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable --now docker
              docker run -d -p 9090:9090 jskeets/custom-prom
              curl -L -O https://grafanarel.s3.amazonaws.com/builds/grafana-2.5.0.linux-x64.tar.gz
              tar zxf grafana-2.5.0.linux-x64.tar.gz
              cd grafana-2.5.0/
              ./bin/grafana-server web
              EOF
}
