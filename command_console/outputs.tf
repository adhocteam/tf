output "sg_id" {
  value = aws_security_group.sg.id
}

output "instance_iam_role" {
  description = "IAM role name for attaching additional policies to the instance with aws_iam_role_policy_attachment"
  value       = aws_iam_role.iam.name
}

