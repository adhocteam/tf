output "key_arn" {
  description = "ARN of the primary encryption key tied to this environment"
  value       = "${module.encryptkey.key_arn}"
}
