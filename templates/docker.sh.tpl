#!/usr/bin/env bash
set -e

apt-get update -y
apt install docker.io -y
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# installing docker-compose
curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version