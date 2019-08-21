output "name" {
  description = "name of the application this hosts"
  value       = var.application_name
}

output "docker_image" {
  description = "Images in the Docker Hub registry are available by default. You can also specify other repositories with either repository-url/image:tag or repository-url/image@digest"
  value       = var.docker_image
}

output "security_group" {
  description = "object with the application-specific security group. defaults to unrestricted egress"
  value       = aws_security_group.fargate
}

output "ecs_execution_iam_role" {
  description = "IAM role name for attaching additional policies to the instance with aws_iam_role_policy_attachment"
  value       = aws_iam_role.ecs_execution
}
