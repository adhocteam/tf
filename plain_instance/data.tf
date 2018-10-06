data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

data "aws_vpc" "vpc" {
  tags {
    env = "${var.env}"
  }
}

data "aws_subnet" "application_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "app-sub-${count.index}"
    env  = "${var.env}"
  }
}

data "aws_secretsmanager_secret_version" "cluster_token" {
  secret_id = "${var.env}/teleport/cluster_token"
}

data "aws_security_group" "ssh_proxies" {
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    env  = "${var.env}"
    app  = "teleport"
    Name = "teleport-proxies"
  }
}

data "aws_security_group" "jumpbox" {
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    env  = "${var.env}"
    app  = "teleport"
    Name = "teleport-jumpbox"
  }
}
