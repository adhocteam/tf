output "listener" {
  description = "an object describing the primary HTTPS listener for other services"
  value       = aws_alb_listener.applications
}

output "security_group" {
  description = "an object describing the primary HTTPS listener for other services"
  value       = aws_security_group.alb
}

output "dns_record" {
  description = "what any external DNS CNAME entries should point to"
  value       = aws_alb.ingress.dns_name
}
