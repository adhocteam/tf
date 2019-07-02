#######
### Lookup resources already created by foundation
#######
data "aws_secretsmanager_secret_version" "cluster_token" {
  secret_id = "${var.base.env}/teleport/cluster_token"
}

data "aws_secretsmanager_secret_version" "github_client_id" {
  secret_id = "${var.base.env}/teleport/github_client_id"
}

data "aws_secretsmanager_secret_version" "github_secret" {
  secret_id = "${var.base.env}/teleport/github_secret"
}

data "aws_secretsmanager_secret" "cluster_token" {
  name = "${var.base.env}/teleport/cluster_token"
}
