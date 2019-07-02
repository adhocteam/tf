terraform {
  required_version = ">= 0.12"
}

# TODO(bob) May need a call to create a service linked role first:
# aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
# seems to be one-time only thing so maybe bootbox?

resource "aws_ecs_cluster" "app" {
  name = var.application_name
}

resource "aws_ecs_task_definition" "app" {
  family = "${var.base.env}-${var.application_name}"
  container_definitions = templatefile("${path.module}/container_task.tmpl", {
    image                 = var.docker_image
    awslogs-group         = aws_cloudwatch_log_group.app.name
    awslogs-region        = var.base.region.name
    awslogs-stream-prefix = "${var.base.env}-${var.application_name}"
    name                  = var.application_name
    cpu_size              = local.cpu_size
    memory_size           = local.memory_size
    portMappings          = jsonencode([for p in var.application_ports : { "containerPort" = "${p}", "hostPort" = "${p}", "protocol" = "tcp" }])
    environment_variables = jsonencode(var.environment_variables)
    secrets               = jsonencode(var.secrets)
  })

  execution_role_arn = aws_iam_role.ecs_execution.arn

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.cpu_size
  memory                   = local.memory_size
}

#####
# Target group to be attached to an LB
#####

resource "aws_alb_target_group" "application" {
  count = length(var.application_ports)
  # max 6 characters for name prefix
  name_prefix = "app-lb"
  port        = var.application_ports[count.index]
  protocol    = "HTTP"
  vpc_id      = var.base.vpc.id
  target_type = "ip" # Must use IP to support fargate

  health_check {
    interval            = 60
    path                = var.health_check_path
    port                = var.application_ports[0]
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = var.application_name
    name      = "app-lb-${var.application_name}-${var.application_ports[count.index]}"
  }
}

locals {
  target_to_ports = zipmap([for t in aws_alb_target_group.application : t.arn], var.application_ports)
}

resource "aws_ecs_service" "application" {
  name            = var.application_name
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets         = var.base.vpc.application[*].id
    security_groups = [aws_security_group.fargate.id]
  }

  load_balancer {
    target_group_arn = keys(local.target_to_ports)[0]
    container_name   = var.application_name
    container_port   = values(local.target_to_ports)[0]
  }


  # Blocked pending support for multiple container ports
  # dynamic "load_balancer" {
  #   for_each = local.target_to_ports
  #   content {
  #     target_group_arn = load_balancer.key
  #     container_name   = var.application_name
  #     container_port   = load_balancer.value
  #   }
  # }

  depends_on = [
    aws_iam_role_policy.ecs_execution
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }
}


#######
# Security group for application
#######

resource "aws_security_group" "fargate" {
  name_prefix = "${var.application_name}-app-"
  vpc_id      = var.base.vpc.id

  tags = {
    app       = var.application_name
    terraform = "true"
    env       = var.base.env
    role      = "fargate"
  }
}

# Allow all outbound, e.g. third-pary API endpoints, by default
resource "aws_security_group_rule" "egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.fargate.id
}

#####
# Centralized logging
#####
resource "aws_cloudwatch_log_group" "app" {
  name = "${var.base.env}-${var.application_name}"

  tags = {
    Name        = "${var.base.env}-${var.application_name}"
    terraform   = "true"
    environment = var.base.env
    app         = var.application_name
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.base.env}-${var.application_name}-ecs_task_execution"
  assume_role_policy = local.assume_role_policy

}

resource "aws_iam_role_policy" "ecs_execution" {
  name   = "${var.base.env}-${var.application_name}-ecs_execution"
  role   = aws_iam_role.ecs_execution.id
  policy = local.iam_role_policy
}

######
# Auto-scaling for ECS cluster
######

resource "aws_appautoscaling_target" "service" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.app.name}/${aws_ecs_service.application.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  max_capacity       = var.max_count
  min_capacity       = var.desired_count
}

# Alarms to trigger actions

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_high" {
  alarm_name          = "${var.base.env}-${var.application_name}-CPU-Utilization-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = 80

  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.application.name
  }

  alarm_description = "Scale up if maximum CPU Utilization is above 80% for two consecutive 5 minute periods"
  alarm_actions     = [aws_appautoscaling_policy.up.arn]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization_high" {
  alarm_name          = "${var.base.env}-${var.application_name}-Memory-Utilization-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "3"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = 90

  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.application.name
  }

  alarm_description = "Scale up if maximum Memory Reservation is above 90% for two consecutive 5 minute periods"
  alarm_actions     = [aws_appautoscaling_policy.up.arn]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = [aws_cloudwatch_metric_alarm.cpu_utilization_high]
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_low" {
  alarm_name          = "${var.base.env}-${var.application_name}-CPU-Utilization-Low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = 20

  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.application.name
  }

  alarm_description = "Scale down if the CPU Utilitization is below 20% for 5 minutes"
  alarm_actions     = [aws_appautoscaling_policy.down.arn]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = [aws_cloudwatch_metric_alarm.memory_utilization_high]
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization_low" {
  alarm_name          = "${var.base.env}-${var.application_name}-Memory-Utilization-Low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = 20

  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.application.name
  }

  alarm_description = "Scale down if the Memory Usage is below 20% for 5 minutes"
  alarm_actions     = [aws_appautoscaling_policy.down.arn]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = [aws_cloudwatch_metric_alarm.cpu_utilization_low]
}

# Autoscaling actions
resource "aws_appautoscaling_policy" "up" {
  name               = "app-scale-up"
  service_namespace  = aws_appautoscaling_target.service.service_namespace
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 2
    }
  }
}

resource "aws_appautoscaling_policy" "down" {
  name               = "app-scale-down"
  service_namespace  = aws_appautoscaling_target.service.service_namespace
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

locals {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  secret_arns = [for s in var.secrets : s["valueFrom"]]
  iam_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecs:StartTelemetrySession",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
      ],
      "Resource": ${local.secret_arns}
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": ${var.base.key.arn}
    }
  ]
}
EOF
}
