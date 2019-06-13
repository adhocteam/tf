terraform {
  required_version = ">= 0.12"
}

module "jumpbox" {
  source      = "./jumpbox"
  env         = var.env
  domain_name = var.domain_name

  # Turned off by default
  enabled = var.jumpbox_enabled
}

module "teleport" {
  source      = "./teleport"
  env         = var.env
  domain_name = var.domain_name
  gh_team     = var.teleport_github_team
}

module "jenkins" {
  source        = "./jenkins"
  env           = var.env
  domain_name   = var.domain_name
  ssh_proxy_sg  = module.teleport.security_group
  workers       = var.jenkins_workers
  jenkins_url   = var.jenkins_url
  jenkins_image = var.jenkins_image
  github_user   = var.jenkins_github_user
}

