module "teleport" {
  source            = "./teleport"
  region            = "${var.region}"
  env               = "${var.env}"
  domain_name       = "${var.domain_name}"
  emergency_jumpbox = "${var.jumpbox}"
}

module "jenkins" {
  source      = "./jenkins"
  env         = "${var.env}"
  domain_name = "${var.domain_name}"
}
