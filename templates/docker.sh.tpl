#!/usr/bin/env bash
set -e

apt-get update -y
apt install docker.io -y
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu
