#!/usr/bin/env bash
set -e

echo "Installing dependencies..."
apt-get -q update
apt-get -yq install apache2

tee /etc/consul.d/webserver-80.json > /dev/null <<"EOF"
{
  "service": {
    "id": "webserver-80",
    "name": "webserver",
    "tags": ["apache"],
    "port": 80,
    "checks": [
      {
        "id": "tcp",
        "name": "TCP on port 80",
        "tcp": "localhost:80",
        "interval": "10s",
        "timeout": "1s"
      },
      {
        "id": "http",
        "name": "HTTP on port 80",
        "http": "http://localhost:80/",
        "interval": "30s",
        "timeout": "1s"
      },
      {
        "id": "service",
        "name": "apache service",
        "args": ["systemctl", "status", "apache2.service"],
        "interval": "60s"
      }
    ]
  }
}
EOF

consul reload

### Install apache Exporter
wget https://github.com/Lusitaniae/apache_exporter/releases/download/v${apache_exporter_version}/apache_exporter-${apache_exporter_version}.linux-amd64.tar.gz -O /tmp/apache_exporter.tgz
mkdir -p ${prometheus_dir}
tar zxf /tmp/apache_exporter.tgz -C ${prometheus_dir}

# Configure node exporter service
tee /etc/systemd/system/apache_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus apache exporter
Requires=network-online.target
After=network.target

[Service]
ExecStart=${prometheus_dir}/apache_exporter-${apache_exporter_version}.linux-amd64/apache_exporter
KillSignal=SIGINT
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable apache_exporter.service
systemctl start apache_exporter.service

