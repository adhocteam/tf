# The connection endpoint in address:port format
output "url" {
  value = aws_route53_record.rds_cname.fqdn
}
