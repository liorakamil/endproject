#!/usr/bin/env bash
set -e

mkdir -p /opt/logging
tee /opt/logging/docker-compose.yml > /dev/null <<EOF
version: "3.4"
x-logging:
  &default-logging
  driver: fluentd

services:
  elasticsearch:
    build:
      context: elasticsearch/
      args:
        ELK_VERSION: $ELK_VERSION
    volumes:
      - type: bind
        source: ./elasticsearch/elasticsearch.yml
        target: /usr/share/elasticsearch/config/elasticsearch.yml
        read_only: true
      - type: volume
        source: elasticsearch
        target: /usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"
    environment:
      ES_JAVA_OPTS: "-Xmx256m -Xms256m"
      ELASTIC_PASSWORD: changeme
      # Use single node discovery in order to disable production mode and avoid bootstrap checks
      # see https://www.elastic.co/guide/en/elasticsearch/reference/current/bootstrap-checks.html
      discovery.type: single-node
    networks:
      - elk

  kibana:
    build:
      context: kibana/
      args:
        ELK_VERSION: $ELK_VERSION
    volumes:
      - type: bind
        source: ./kibana/kibana.yml
        target: /usr/share/kibana/config/kibana.yml
        read_only: true
    ports:
      - "5601:5601"
    networks:
      - elk
    depends_on:
      - elasticsearch

networks:
  elk:
    driver: bridge

volumes:
  elasticsearch:
EOF

#create logging/elasticsearch.yml, Dockerfile:

mkdir -p /opt/logging/elasticsearch
tee /opt/logging/elasticsearch/elasticsearch.yml > /dev/null <<EOF
## Default Elasticsearch configuration from Elasticsearch base image.
## https://github.com/elastic/elasticsearch/blob/master/distribution/docker/src/docker/config/elasticsearch.yml
#
cluster.name: "docker-cluster"
network.host: 0.0.0.0

## X-Pack settings
## see https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-xpack.html
#
xpack.license.self_generated.type: trial
xpack.security.enabled: true
xpack.monitoring.collection.enabled: true
EOF

tee /opt/logging/elasticsearch/Dockerfile > /dev/null <<EOF
ARG ELK_VERSION

FROM docker.elastic.co/elasticsearch/elasticsearch:7.6.0
EOF


#create logging/kibana.yml:

mkdir -p /opt/logging/kibana
tee /opt/logging/kibana/kibana.yml > /dev/null <<EOF
## Default Kibana configuration from Kibana base image.
## https://github.com/elastic/kibana/blob/master/src/dev/build/tasks/os_packages/docker_generator/templates/kibana_yml.template.js
#
server.name: kibana
server.host: "0"
elasticsearch.hosts: [ "http://elasticsearch:9200" ]
xpack.monitoring.ui.container.elasticsearch.enabled: true

## X-Pack security credentials
#
elasticsearch.username: elastic
elasticsearch.password: changeme
EOF

tee /opt/logging/kibana/Dockerfile > /dev/null <<EOF
ARG ELK_VERSION

FROM docker.elastic.co/kibana/kibana:7.6.0
EOF

# Configure logging service
tee /etc/systemd/system/logging.service > /dev/null <<EOF
[Unit]
Description=logging Containers
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
WorkingDirectory=/opt/logging
ExecStartPre=-/usr/local/bin/docker-compose down --remove-orphans
ExecStart=/usr/local/bin/docker-compose up

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable logging.service
systemctl start logging.service

### add logging service to consul
tee /etc/consul.d/elasticsearch-9200.json > /dev/null <<"EOF"
{
  "service": {
    "id": "elasticsearch-9200",
    "name": "elasticsearch",
    "tags": ["elasticsearch"],
    "port": 9200,
    "checks": [
      {
        "id": "tcp",
        "name": "TCP on port 9300",
        "tcp": "localhost:9300",
        "interval": "10s",
        "timeout": "1s"
      },
      {
        "id": "http",
        "name": "HTTP on port 9200",
        "header": {"Authorization":["Basic ${elastic_base64}"]},
        "http": "http://localhost:9200/_cluster/health",
        "interval": "30s",
        "timeout": "1s"
      },
      {
        "id": "service",
        "name": "logging",
        "args": ["systemctl", "status", "logging"],
        "interval": "60s"
      }
    ]
  }
}
EOF

### add prometheus discovery with consul:
tee /etc/consul.d/node-exporter.json > /dev/null <<"EOF"
{
  "service":
  {"name": "node-exporter-logging",
   "tags": ["node_exporter", "prometheus"],
   "port": 9100
  }
}
EOF

consul reload