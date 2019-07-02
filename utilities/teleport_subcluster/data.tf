#######
### Lookup resources already created by foundation
#######

data "aws_region" "current" {
}

data "aws_vpc" "vpc" {
  tags = {
    env = var.env
  }
}

data "aws_subnet" "application_subnet" {
  count  = 3
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    name = "app-sub-${count.index}"
    env  = var.env
  }
}

data "aws_kms_key" "main" {
  key_id = "alias/${var.env}-main"
}

data "aws_secretsmanager_secret_version" "cluster_token" {
  secret_id = "${var.env}/teleport/cluster_token"
}

data "aws_secretsmanager_secret_version" "main_cluster_token" {
  secret_id = "${var.main_cluster}/teleport/cluster_token"
}

data "aws_security_group" "jumpbox" {
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    env  = var.env
    app  = "utilities"
    Name = "jumpbox"
  }
}

data "aws_ami" "base" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["adhoc_base*"]
  }
}

