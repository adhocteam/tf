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

data "aws_subnet" "public_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "public-sub-${count.index}"
    env  = "${var.env}"
  }
}

data "aws_route53_zone" "external" {
  name         = "${var.domain_name}"
  private_zone = false
}

data "aws_route53_zone" "internal" {
  name         = "${var.env}.local"
  private_zone = true
}

data "aws_ami" "base" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["self"]
  }

  filter {
    name   = "name"
    values = ["adhoc_base*"]
  }
}
