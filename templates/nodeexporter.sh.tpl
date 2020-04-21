#!/bin/bash

# This script downloads and installs node_exporter of the requested version on a host.
# node_exporter is set up as a systemd service, which requiers a daemon-reload.
# BLAME: DamDam (Adam Bihari)

node_exporter_ver="0.18.0"

wget \
  https://github.com/prometheus/node_exporter/releases/download/v$node_exporter_ver/node_exporter-$node_exporter_ver.linux-amd64.tar.gz \
  -O /tmp/node_exporter-$node_exporter_ver.linux-amd64.tar.gz

tar zxvf /tmp/node_exporter-$node_exporter_ver.linux-amd64.tar.gz

cp ./node_exporter-$node_exporter_ver.linux-amd64/node_exporter /usr/local/bin

useradd --no-create-home --shell /bin/false node_exporter

chown node_exporter:node_exporter /usr/local/bin/node_exporter

mkdir -p /var/lib/node_exporter/textfile_collector
chown node_exporter:node_exporter /var/lib/node_exporter
chown node_exporter:node_exporter /var/lib/node_exporter/textfile_collector

tee /etc/systemd/system/node_exporter.service &>/dev/null << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --collector.textfile.directory /var/lib/node_exporter/textfile_collector \
 --no-collector.infiniband

[Install]
WantedBy=multi-user.target
EOF

rm -rf /tmp/node_exporter-$node_exporter_ver.linux-amd64.tar.gz \
  ./node_exporter-$node_exporter_ver.linux-amd64

#create textfile collector metrics
tee /var/lib/node_exporter/textfile_collector/metrics.prom > /dev/null <<EOF
node_memory_MemFree_bytes
node_cpu_seconds_total
node_filesystem_avail_bytes
rate(node_cpu_seconds_total{mode="system"}[1m])
rate(node_network_receive_bytes_total[1m])
EOF

systemctl daemon-reload

systemctl start node_exporter

systemctl status --no-pager node_exporter

systemctl enable node_exporter



