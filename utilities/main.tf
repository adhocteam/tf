terraform {
  required_version = ">= 0.12"
}

module "jumpbox" {
  source = "./jumpbox"

  base = var.base
  # Turned off by default
  enabled = var.jumpbox_enabled
}

module "teleport" {
  source = "./teleport"

  base    = var.base
  gh_team = var.teleport_github_team
}

module "jenkins" {
  source = "./jenkins"

  base        = var.base
  ingress     = var.ingress
  workers     = var.jenkins_workers
  image_tag   = var.jenkins_image
  github_user = var.jenkins_github_user
}

