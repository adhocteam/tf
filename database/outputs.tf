# The connection endpoint in address:port format
output "url" {
  value = aws_route53_record.rds_cname.fqdn
}

output "security_group" {
  description = "security group for the database"
  value       = aws_security_group.database
}
