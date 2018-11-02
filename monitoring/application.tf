resource "aws_security_group" "prometheus" {
  name        = "prometheusserver"
  description = "Public HTTP + SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 9090
      to_port = 9090
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 3000
      to_port = 3000
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 9100
      to_port = 9100
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

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

# resource "aws_instance" "web" {
#   ami           = "ami-0bdb828fd58c52235" 
#   instance_type          = "t2.micro"
#   vpc_security_group_ids = [ "${aws_security_group.prometheus.id}" ]
#   key_name = "infrastructure"
# #  SYSTEMD USER DATA FOR LINUX 2
# #   user_data = <<-EOF
# #               #!/bin/bash
# #               yum update -y
# #               wget https://github.com/prometheus/node_exporter/releases/download/v0.15.2/node_exporter-0.15.2.linux-amd64.tar.gz
# #               tar -xf node_exporter-0.15.2.linux-amd64.tar.gz
# #               sudo mv node_exporter-0.15.2.linux-amd64/node_exporter /usr/local/bin
# #               sudo useradd -rs /bin/false node_exporter
# #               echo "[Unit]
# #                  Description=Node Exporter
# #                  After=network.target

# #                  [Service]
# #                   User=node_exporter
# #                   Group=node_exporter 
# #                   Type=simple
# #                   ExecStart=/usr/local/bin/node_exporter
                
# #                  [Install]
# #                   WantedBy=multi-user.target" > /etc/systemd/system/node_exporter.service
# #               sudo systemctl daemon-reload
# #               sudo systemctl enable node_exporter
# #               sudo systemctl start node_exporter
# #               EOF

# user_data = <<-EOF
#             #!/bin/bash
#             yum update -y
#             wget https://github.com/prometheus/node_exporter/releases/download/v0.15.2/node_exporter-0.15.2.linux-amd64.tar.gz
#             tar -xf node_exporter-0.15.2.linux-amd64.tar.gz
#             sudo cp node_exporter-0.15.2.linux-amd64/node_exporter /usr/local/bin/
#             sudo /usr/local/bin/node_exporter
#             sudo /usr/local/bin/node_exporter --collector.loadavg --collector.meminfo --collector.filesystem
#             EOF

# }

resource "aws_instance" "prom" {
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "t2.micro"
  key_name      = "infrastructure"
  vpc_security_group_ids = [ "${aws_security_group.prometheus.id}" ]

  tags {
    Name      = "prometheus-monitor"
  }


  associate_public_ip_address = false
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable --now docker
              docker run -d -p 9090:9090 jskeets/custom-prom
              curl -L -O https://grafanarel.s3.amazonaws.com/builds/grafana-2.5.0.linux-x64.tar.gz
              tar zxf grafana-2.5.0.linux-x64.tar.gz
              cd grafana-2.5.0/
              ./bin/grafana-server web
              EOF

  lifecycle {
    ignore_changes = ["ami"]
  }
}

output "prom_public_dns" {
  value = "${aws_instance.prom.public_dns}"
}

# output "web_public_dns" {
#   value = "${aws_instance.web.public_dns}"
# }
