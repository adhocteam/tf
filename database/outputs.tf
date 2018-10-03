# The connection endpoint in address:port format
output "database-url" {
  value = "${var.app-name}-db-primary.${var.name}.local"
}
