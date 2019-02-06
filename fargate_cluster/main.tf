module "fargate_base" {
  source = "../app_base"

  env               = "${var.env}"
  domain_name       = "${var.domain_name}"
  application_name  = "${var.application_name}"
  application_port  = "${var.application_port}"
  loadbalancer_port = "${var.loadbalancer_port}"
  health_check_path = "${var.health_check_path}"
}

# TODO(bob) May need a call to create a service linked role first:
# aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
# seems to be one-time only thing so maybe bootbox?

resource "aws_ecs_cluster" "app" {
  name = "${var.application_name}"
}

# Must use template here to get ports as ints
data "template_file" "task" {
  template = "${file("${path.module}/container_task.json")}"

  vars {
    image                 = "${var.docker_image}"
    awslogs-group         = "${aws_cloudwatch_log_group.app.name}"
    awslogs-region        = "${data.aws_region.current.name}"
    awslogs-stream-prefix = "${var.env}-${var.application_name}"
    name                  = "${var.application_name}"
    port                  = "${var.application_port}"
    environment_variables = "${jsonencode(var.environment_variables)}"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                = "${var.env}-${var.application_name}"
  container_definitions = "${data.template_file.task.rendered}"
  execution_role_arn    = "${aws_iam_role.ecs_execution.arn}"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "2048"      # 2 vCPU
  memory                   = "4096"      # 4 GiB
}

resource "aws_ecs_service" "application" {
  name            = "${var.application_name}"
  cluster         = "${aws_ecs_cluster.app.id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = ["${data.aws_subnet.application_subnet.*.id}"]
    security_groups = ["${module.fargate_base.app_sg_id}"]
  }

  load_balancer {
    target_group_arn = "${module.fargate_base.lb_tg_arn}"
    container_name   = "${var.application_name}"
    container_port   = "${var.application_port}"
  }

  depends_on = [
    # https://www.terraform.io/docs/providers/aws/r/ecs_service.html
    # Note: To prevent a race condition during service deletion,
    # make sure to set depends_on to the related aws_iam_role_policy;
    # otherwise, the policy may be destroyed too soon and
    # the ECS service will then get stuck in the DRAINING state.
    "aws_iam_role_policy.ecs_execution",

    # This prevents errors with the load balancer targeting group
    # not being linked yet causing invalid parameter errors
    "module.fargate_base",
  ]

  lifecycle {
    ignore_changes = [
      # Ignore changes to the desired count (which may be due to autoscaling)
      "desired_count",
    ]
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name = "${var.env}-${var.application_name}"

  tags {
    Name        = "${var.env}-${var.application_name}"
    environment = "${var.env}"
    app         = "${var.application_name}"
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.env}-${var.application_name}-ecs_task_execution"

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
}

resource "aws_iam_role_policy" "ecs_execution" {
  name = "${var.env}-${var.application_name}-ecs_execution"
  role = "${aws_iam_role.ecs_execution.id}"

  policy = <<EOF
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
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

######
# Auto-scaling for ECS cluster
######

resource "aws_appautoscaling_target" "service" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.app.name}/${aws_ecs_service.application.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  max_capacity       = 8
  min_capacity       = 2
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_high" {
  alarm_name          = "${var.env}-${var.application_name}-CPU-Utilization-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = 80

  dimensions {
    ClusterName = "${aws_ecs_cluster.app.name}"
    ServiceName = "${aws_ecs_service.application.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.up.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_low" {
  alarm_name          = "${var.env}-${var.application_name}-CPU-Utilization-High"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = 40

  dimensions {
    ClusterName = "${aws_ecs_cluster.app.name}"
    ServiceName = "${aws_ecs_service.application.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.down.arn}"]
}

resource "aws_appautoscaling_policy" "up" {
  name               = "app-scale-up"
  service_namespace  = "${aws_appautoscaling_target.service.service_namespace}"
  resource_id        = "${aws_appautoscaling_target.service.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.service.scalable_dimension}"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "down" {
  name               = "app-scale-down"
  service_namespace  = "${aws_appautoscaling_target.service.service_namespace}"
  resource_id        = "${aws_appautoscaling_target.service.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.service.scalable_dimension}"

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
