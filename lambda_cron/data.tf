data "aws_s3_bucket" "releases" {
  bucket = "${var.domain_name}-${var.env}-lambda-releases"
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

data "aws_kms_alias" "main" {
  name = "alias/${var.env}-main"
}
