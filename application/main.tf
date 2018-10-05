#######
### Lookup resources already created by foundation
#######

data "aws_vpc" "vpc" {
  tags {
    env = "${var.name}"
  }
}

#######
### Security group for application
#######

resource "aws_security_group" "app_sg" {
  name_prefix = "${var.application_name}-app-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    app = "${var.application_name}"
    env = "${var.name}"
  }
}

// Allow inbound only to our application ports
resource "aws_security_group_rule" "ingress" {
  count       = "${length(var.application_ports)}"
  type        = "ingress"
  from_port   = "${element(var.application_ports, count.index)}"
  to_port     = "${element(var.application_ports, count.index)}"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.app_sg.id}"
}

// Allow all outbound, e.g. third-pary API endpoints, by default
resource "aws_security_group_rule" "egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.app_sg.id}"
}
