# data "aws_security_group" "ssh_proxies" {
#   vpc_id = data.aws_vpc.vpc.id

#   tags = {
#     env  = var.env
#     app  = "teleport"
#     Name = "teleport-proxies"
#   }
# }

# data "aws_security_group" "jumpbox" {
#   vpc_id = data.aws_vpc.vpc.id

#   tags = {
#     env  = var.env
#     app  = "utilities"
#     Name = "jumpbox"
#   }
# }

data "aws_secretsmanager_secret" "cluster_token" {
  name = "${var.base.env}/teleport/cluster_token"
}
