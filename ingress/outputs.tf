output "listener" {
  description = "an object describing the primary HTTPS listener for other services"
  value       = aws_alb_listener.applications
}

output "security_group" {
  description = "an object describing the primary HTTPS listener for other services"
  value       = aws_security_group.alb
}
