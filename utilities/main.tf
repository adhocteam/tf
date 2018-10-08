### This is a convenience for installing the basic set of ulitities
### To customize, just import the ones you want directly

module "teleport" {
 source            = "./teleport"
 region            = "${var.region}"
 env               = "${var.env}"
 domain_name       = "${var.domain_name}"
}

module "jenkins" {
  source      = "./jenkins"
  env         = "${var.env}"
  domain_name = "${var.domain_name}"
}
