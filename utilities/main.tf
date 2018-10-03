module "teleport" {
  source            = "./teleport"
  region            = "${var.region}"
  name              = "${var.name}"
  domain_name       = "${var.domain_name}"
  emergency_jumpbox = 1
}
