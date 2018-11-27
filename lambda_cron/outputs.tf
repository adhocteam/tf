output "job_iam_role" {
  description = "IAM role name for attaching additional policies to the lambda function with aws_iam_role_policy_attachment"
  value       = "${aws_iam_role.job.name}"
}
