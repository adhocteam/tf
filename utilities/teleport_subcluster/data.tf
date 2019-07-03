#######
### Lookup resources already created by foundation
#######
data "aws_secretsmanager_secret_version" "cluster_token" {
  secret_id = "${var.base.env}/teleport/cluster_token"
}

data "aws_secretsmanager_secret_version" "main_cluster_token" {
  secret_id = "${var.main_cluster}/teleport/cluster_token"
}
