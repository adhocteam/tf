Currently this terraform file will spin up two instances one which contains the prometheus monitor and another which spins up a blank instance with node exporter installed

There are two different ways of installing node exporter. One is if the host machine has the ability to run `systemd` which is not available on amazon linux ami, only on amazon linux 2 amis

This user data script will install and start node exporter on the blank machine

  SYSTEMD USER DATA FOR LINUX 2
#   user_data = <<-EOF
#               #!/bin/bash
#               yum update -y
#               wget https://github.com/prometheus/node_exporter/releases/download/v0.15.2/node_exporter-0.15.2.linux-amd64.tar.gz
#               tar -xf node_exporter-0.15.2.linux-amd64.tar.gz
#               sudo mv node_exporter-0.15.2.linux-amd64/node_exporter /usr/local/bin
#               sudo useradd -rs /bin/false node_exporter
#               echo "[Unit]
#                  Description=Node Exporter
#                  After=network.target

#                  [Service]
#                   User=node_exporter
#                   Group=node_exporter 
#                   Type=simple
#                   ExecStart=/usr/local/bin/node_exporter
                
#                  [Install]
#                   WantedBy=multi-user.target" > /etc/systemd/system/node_exporter.service
#               sudo systemctl daemon-reload
#               sudo systemctl enable node_exporter
#               sudo systemctl start node_exporter
#               EOF



Node exporter can be installed on a linux one machine via the following user data script

user_data = <<-EOF
            #!/bin/bash
            yum update -y
            wget https://github.com/prometheus/node_exporter/releases/download/v0.15.2/node_exporter-0.15.2.linux-amd64.tar.gz
            tar -xf node_exporter-0.15.2.linux-amd64.tar.gz
            sudo cp node_exporter-0.15.2.linux-amd64/node_exporter /usr/local/bin/
            sudo /usr/local/bin/node_exporter
            sudo /usr/local/bin/node_exporter --collector.loadavg --collector.meminfo --collector.filesystem
            EOF


## SETUP
 Once the prometheus monitor is set up you can go to the public url:3000 and login to the grafana dashboard with admin/admin

 The prometheus data source must be added to the dashboard. 

 On the top left click on the grafana symbol > Data sources > Add new 
  Name: Prometheus
  Type: Prometheus

Set the URL equal to the url of the prometheus monitor:9090. Test the connection and it should be good. 

You will now have to import a dashbaord. Prometheus will auto discover servers with node exporter installed which exist in the same region. 

Dashboard > (Dropdown menu that says home) > import > choose file >



## General Overview.
 Node exporter exposed the metrics of the instance on port :9100/metrics
 Prometheus operates on :9090
 Grafana operates on port :3000
 Prometheus will automatically discover instances which have node exporter installed on them as long as the monitor and the instance are in the same region. 


 ## Things that need to be accomplished
  Node exporter will run just fine if initated through terraform with the current script. If node exporter is initiated with the current script via SSHing into the instance it will close the port as soon as the SSH connection is shut down.

  - Docker image needs to be made more secure by hiding 