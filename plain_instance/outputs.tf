output "app_sg_id" {
  value = "${module.base.app_sg_id}"
}

output "instance_iam_role" {
  description = "IAM role name for attaching additional policies to the instance with aws_iam_role_policy_attachment"
  value       = "${aws_iam_role.iam.name}"
}
