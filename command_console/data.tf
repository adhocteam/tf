data "aws_vpc" "vpc" {
  tags {
    env = "${var.env}"
  }
}

data "aws_caller_identity" "current" {}

data "aws_subnet" "application_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "app-sub-${count.index}"
    env  = "${var.env}"
  }
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
