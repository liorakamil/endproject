#!/usr/bin/env bash
set -e

# install fluentd from https://docs.fluentd.org/installation/install-by-deb
curl -L https://toolbelt.treasuredata.com/sh/install-ubuntu-bionic-td-agent3.sh | sh

apt-get install make libcurl4-gnutls-dev --yes
/opt/td-agent/embedded/bin/fluent-gem install fluent-plugin-elasticsearch

### TODO: Configure FluentD
tee /etc/td-agent/td-agent.conf > /dev/null <<EOF
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>
<source>
  @type syslog
  port 5140
  tag system
</source>
<filter **>
  @type record_transformer
  <record>
    hostname "#{Socket.gethostname}"
  </record>
</filter>
<match **>
  @type elasticsearch
  host ${elasticsearch_host}
  port 9200
  user ${elasticsearch_user}
  password ${elasticsearch_password}
  logstash_format true
</match>
EOF

systemctl daemon-reload
systemctl enable td-agent.service
systemctl start td-agent.service