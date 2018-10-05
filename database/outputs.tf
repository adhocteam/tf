# The connection endpoint in address:port format
output "database_url" {
  value = "${var.app-name}-db-primary.${var.name}.local"
}
