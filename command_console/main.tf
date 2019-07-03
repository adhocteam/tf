terraform {
  required_version = ">= 0.12"
}

module "console" {
  source = "../instance"

  base             = var.base
  application_name = "${var.fargate_cluster.name}-command-console"
  instance_size    = "t3.medium"

  user_data = templatefile("${path.module}/user_data.tmpl", {
    docker_image          = var.fargate_cluster.docker_image
    environment_variables = var.environment_variables
    command               = var.default_command
  })
}

resource "aws_iam_role_policy_attachment" "console_ecr" {
  role       = "${module.console.instance_iam_role}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_security_group_rule" "database" {
  count                    = length(var.database) > 0 ? 1 : 0
  type                     = "ingress"
  from_port                = "5432"
  to_port                  = "5432"
  protocol                 = "tcp"
  source_security_group_id = "${module.console.security_group.id}"

  security_group_id = "${var.database.security_group.id}"
}

