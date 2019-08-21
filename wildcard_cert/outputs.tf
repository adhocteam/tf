
locals {
  arn = var.primary ? aws_acm_certificate.domain[0].arn : data.aws_acm_certificate.primary[0].arn
}
output "arn" {
  value = local.arn
}

