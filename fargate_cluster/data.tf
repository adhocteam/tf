data "aws_region" "current" {}

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
