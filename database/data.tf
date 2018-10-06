####
# Pull in external data for use here
####

data "aws_route53_zone" "internal" {
  name         = "${var.env}.local"
  private_zone = true
}

data "aws_vpc" "vpc" {
  tags {
    env = "${var.env}"
  }
}

data "aws_subnet" "data_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "data-sub-${count.index}"
    env  = "${var.env}"
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

data "aws_kms_key" "main" {
  key_id = "alias/${var.env}-main"
}
