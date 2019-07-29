#! /usr/bin/env bash
set -euo pipefail

echo "--- Install yum packages"
sudo yum -y -q update
sudo amazon-linux-extras install docker &> /dev/null
sudo yum install -y -q curl git jq docker yum-cron

echo "--- Configure yum packages"
# Allow sudo-less docker commands
sudo usermod -aG docker ec2-user

# Move yum-cron config into place for automated security updates
sudo mv /tmp/files/yum-cron.conf /etc/yum/yum-cron.conf
sudo chmod 0644 /etc/yum/yum-cron.conf

echo "--- Install docker-compose"
# Install docker-compose
COMPOSE_URL=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -rc '.assets[] | select(.name == "docker-compose-Linux-x86_64") | .browser_download_url')
sudo curl -sSfo /usr/local/bin/docker-compose "${COMPOSE_URL}"
sudo chmod 0755 /usr/local/bin/docker-compose
sudo chown ec2-user:ec2-user /usr/local/bin/docker-compose

echo "--- Install teleport"
# Create a system user with a locked password for teleport
sudo useradd -d "/var/lib/teleport/" -g "adm" -k "/dev/null" -m -r -s "/sbin/nologin" teleport
sudo passwd -l teleport

# Download info on the teleport release we are targeting
TELEPORT_VERSION="v4.0.2"
TELEPORT_INFO=$(curl -sSf https://dashboard.gravitational.com/webapi/releases-oss?product=teleport | jq ".items | map(select(.version == \"${TELEPORT_VERSION}\")) | .[].downloads | map(select(.name == \"teleport-${TELEPORT_VERSION}-linux-amd64-bin.tar.gz\")) | .[]")

# Install teleport binaries
cd $(mktemp -d)
curl -sSfo teleport.tar.gz "$(echo ${TELEPORT_INFO} | jq -r .url)"
echo "$(echo ${TELEPORT_INFO} | jq -r .sha256) teleport.tar.gz" > teleport.tar.gz.sum
sha256sum -c --status teleport.tar.gz.sum
tar xzf teleport.tar.gz
sudo cp teleport/{tctl,teleport} /usr/local/bin/
sudo chown teleport:adm /usr/local/bin/{tctl,teleport}
cd -

# Install teleports secrets script
sudo cp /tmp/files/teleport/teleport-secrets /usr/local/bin
sudo chown teleport:adm /usr/local/bin/teleport-secrets
sudo chmod 0755 /usr/local/bin/teleport-secrets

echo "--- Configure teleport"
# Install teleport configuration
sudo cp /tmp/files/teleport/teleport.yaml.tmpl /etc
sudo chmod 0644 /etc/teleport.yaml.tmpl

# Install teleport systemd units
sudo cp /tmp/files/teleport/*.service /etc/systemd/system
sudo chmod 0644 /etc/systemd/system/teleport*

echo "--- Turn on systemd services"
sudo systemctl enable docker
sudo systemctl enable yum-cron
sudo systemctl enable teleport

echo "--- Turn off systemd services"
sudo systemctl disable --now amazon-ssm-agent
