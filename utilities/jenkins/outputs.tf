output "worker_iam_role" {
  description = "IAM role name for attaching additional policies for the worker with aws_iam_role_policy_attachment"
  value       = aws_iam_role.worker.name
}

