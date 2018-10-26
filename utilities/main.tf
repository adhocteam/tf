module "teleport" {
  source      = "./teleport"
  env         = "${var.env}"
  domain_name = "${var.domain_name}"
}

module "jenkins" {
  source      = "./jenkins"
  env         = "${var.env}"
  domain_name = "${var.domain_name}"
}

# Disabled by default
module "jumpbox" {
  source      = "./jumpbox"
  env         = "${var.env}"
  domain_name = "${var.domain_name}"
}
