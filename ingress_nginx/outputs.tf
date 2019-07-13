output "listener" {
  description = "an object describing the primary HTTPS listener for other services"
  value       = module.alb.listener
}

output "security_group" {
  description = "an object describing the primary HTTPS listener for other services"
  value       = module.alb.security_group
}

output "dns_record" {
  description = "what any external DNS CNAME entries should point to"
  value       = aws_lb.nlb.dns_name
}
