data "aws_acm_certificate" "pizza_cert_wildcard" {
  domain   = "adhoc.pizza"
  statuses = ["ISSUED"]
}

# Find the newest Amazon Linux 2 AMI to keep up to date on patches
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
