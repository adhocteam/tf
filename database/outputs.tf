# The connection endpoint in address:port format
output "url" {
  value = aws_route53_record.rds_cname.fqdn
}

output "security_group_id" {
  value = aws_security_group.db_sg.id
}

