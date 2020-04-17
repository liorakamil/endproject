#!/usr/bin/env bash
set -e

### Install Prometheus Collector
wget https://github.com/prometheus/prometheus/releases/download/v${promcol_version}/prometheus-${promcol_version}.linux-amd64.tar.gz -O /tmp/promcoll.tgz
mkdir -p ${prometheus_dir}
tar zxf /tmp/promcoll.tgz -C ${prometheus_dir}

# Create promcol configuration
mkdir -p ${prometheus_conf_dir}

tee ${prometheus_conf_dir}/prometheus.yml > /dev/null <<EOF
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['${prometheus_host}:9090']

  - job_name: 'node-exporter'
    consul_sd_configs:
      - server: 'localhost:8500'
    # All hosts detected will use port 9100 for node-exporter
    relabel_configs:
      - source_labels: ['__address__']
        separator:     ':'
        regex:         '(.*):(.*)'
        target_label:  '__address__'
        replacement:   '$1:9100'
    #   replacement:   '\$1:9100'
      - source_labels: [__meta_consul_node]
        target_label: instance

  - job_name: 'consul-exporter'
    consul_sd_configs:
      - server: 'localhost:8500'
    relabel_configs:
      - source_labels: ['__meta_consul_service']
        regex:  '^consul$' 
        target_label: job
        # This will drop all targets that do not match the regex rule,
        # leaving only the 'apache' targets
        action: 'keep'
      - source_labels: []
        replacement:   '/v1/agent/metrics?format=prometheus'
        target_label: __metrics_path__
      - source_labels: ['__address__']
        separator:     ':'
        regex:         '(.*):(.*)'
        target_label:  '__address__'
        replacement:   '$1:8500'
    #   replacement:   '\$1:8500'
      - source_labels: [__meta_consul_node]
        target_label: instance
EOF

# Configure promcol service
tee /etc/systemd/system/promcol.service > /dev/null <<EOF
[Unit]
Description=Prometheus Collector
Requires=network-online.target
After=network.target

[Service]
ExecStart=${prometheus_dir}/prometheus-${promcol_version}.linux-amd64/prometheus --config.file=${prometheus_conf_dir}/prometheus.yml
ExecReload=/bin/kill -s HUP \$MAINPID
KillSignal=SIGINT
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promcol.service
systemctl start promcol.service