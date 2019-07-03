output "name" {
  description = "name of the application this hosts"
  value       = var.application_name
}

output "security_group" {
  description = "object with the application-specific security group. defaults to unrestricted egress"
  value       = aws_security_group.fargate
}

output "ecs_execution_iam_role" {
  description = "IAM role name for attaching additional policies to the instance with aws_iam_role_policy_attachment"
  value       = aws_iam_role.ecs_execution
}

output "target_group" {
  description = "Load balancer target group pointing at all of the instances"
  value       = aws_alb_target_group.application
}

output "docker_image" {
  description = "the docker image running in the fargate cluster"
  value       = "var.docker_image"
}
