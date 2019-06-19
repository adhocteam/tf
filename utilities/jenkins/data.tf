data "aws_secretsmanager_secret" "cluster_token" {
  name = "${var.env}/teleport/cluster_token"
}

data "aws_secretsmanager_secret_version" "github_client_id" {
  secret_id = "${var.env}/jenkins/github_client_id"
}

data "aws_secretsmanager_secret_version" "github_client_secret" {
  secret_id = "${var.env}/jenkins/github_client_secret"
}

data "aws_secretsmanager_secret_version" "github_password" {
  secret_id = "${var.env}/jenkins/github_password"
}

data "aws_secretsmanager_secret_version" "slack_token" {
  secret_id = "${var.env}/jenkins/slack_token"
}

data "aws_secretsmanager_secret_version" "docker_password" {
  secret_id = "${var.env}/jenkins/docker_password"
}
