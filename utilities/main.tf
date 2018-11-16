module "jumpbox" {
  source      = "./jumpbox"
  env         = "${var.env}"
  domain_name = "${var.domain_name}"

  # Turned off by default
  enabled = "${var.jumpbox_enabled}"
}

module "teleport" {
  source      = "./teleport"
  env         = "${var.env}"
  domain_name = "${var.domain_name}"
  jumpbox_sg  = "${module.jumpbox.security_group}"
}

module "jenkins" {
  source       = "./jenkins"
  env          = "${var.env}"
  domain_name  = "${var.domain_name}"
  jumpbox_sg   = "${module.jumpbox.security_group}"
  ssh_proxy_sg = "${module.teleport.security_group}"
  workers      = "${var.jenkins_workers}"
}
