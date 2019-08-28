output "env" {
  description = "name of the environment that we are creating"
  value       = var.env
}

output "domain_name" {
  description = "domain name we are using for resources hosted in this environment"
  value       = var.domain_name
}
output "external" {
  description = "object of the route53 zone for public DNS"
  value       = data.aws_route53_zone.external
}
output "account" {
  description = "account number of the current targeted AWS account"
  value       = data.aws_caller_identity.current
}

output "ami" {
  description = "custom ami base for the VPC"
  value       = data.aws_ami.base
}

output "region" {
  description = "current aws region"
  value       = data.aws_region.current
}

output "vpc" {
  description = "an object with the outputs of the vpc module"
  value       = module.vpc
}

output "key" {
  description = "the primary encryption key tied to this environment"
  value       = module.encryptkey
}

output "ssh_key" {
  description = "default ssh key pair to use for jumpbox and application instances"
  value       = var.ssh_key
}

output "wildcard" {
  description = "wildcard certificate for the primary domain_name"
  value       = module.wildcard
}

output "ingress" {
  description = "an ALB for applications to connect to in order to receive public traffic"
  value       = module.ingress
}

output "security_groups" {
  description = "a map of names to security groups that are shared throughout the vpc"
  value = {
    "teleport_proxies" = aws_security_group.teleport_proxies
    "teleport_nodes"   = aws_security_group.teleport_nodes
    "jumpbox"          = aws_security_group.jumpbox
    "jumpbox_nodes"    = aws_security_group.jumpbox_nodes
    "prometheus"       = aws_security_group.prometheus
    "node_exporter"    = aws_security_group.node_exporter
  }
}

output "lambda_releases" {
  description = "object for the S3 bucket to hold lambda function release zips"
  value       = aws_s3_bucket.lambda_releases
}
