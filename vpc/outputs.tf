output "id" {
  description = "id of the primary VPC created by the module"
  value       = aws_vpc.primary.id
}

output "cidr_block" {
  description = "the CIDR block to provisioned in the VPC. it is a /16 block"
  value       = var.cidr_block
}

output "internal_dns" {
  description = "the internal dns zone for the vpc"
  value       = aws_route53_zone.internal
}

output "application" {
  description = "list of application subnets in the VPC"
  value       = aws_subnet.application[*]
}

output "public" {
  description = "list of public subnets in the VPC"
  value       = aws_subnet.public[*]
}

output "data" {
  description = "list of database subnets in the VPC"
  value       = aws_subnet.data[*]
}

