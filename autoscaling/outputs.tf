output "name" {
  description = "name of the application this hosts"
  value       = var.application_name
}

output "security_group" {
  description = "object with the application-specific security group. defaults to unrestricted egress"
  value       = aws_security_group.app
}

output "instance_iam_role" {
  description = "IAM role name for attaching additional policies to the instance with aws_iam_role_policy_attachment"
  value       = aws_iam_role.iam
}

output "target_group" {
  description = "Load balancer target group pointing at all of the instances"
  value       = aws_alb_target_group.application
}
