data "aws_secretsmanager_secret" "cluster_token" {
  name = "${var.base.env}/teleport/cluster_token"
}
