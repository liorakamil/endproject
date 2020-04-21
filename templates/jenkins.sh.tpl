#!/usr/bin/env bash
set -e

mkdir -p /home/ubuntu/jenkins_home
chown -R 1000:1000 /home/ubuntu/jenkins_home

# Configure jenkins service
tee /etc/systemd/system/jenkins.service > /dev/null <<EOF
[Unit]
Description=Jenkins Container
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop jenkins
ExecStartPre=-/usr/bin/docker rm jenkins
ExecStart=/usr/bin/docker run --rm -p 8080:8080 -p 50000:50000 --name jenkins -v /home/ubuntu/jenkins_home:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock --env JAVA_OPTS='-Djenkins.install.runSetupWizard=false' --log-driver fluentd liorakamil/jenkins:withpins

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable jenkins.service
systemctl start jenkins.service

### add jenkins service to consul
tee /etc/consul.d/jenkins-8080.json > /dev/null <<"EOF"
{
  "service": {
    "id": "jenkins-8080",
    "name": "jenkins-master",
    "tags": ["jenkins"],
    "port": 8080,
    "checks": [
      {
        "id": "tcp",
        "name": "TCP on port 8080",
        "tcp": "localhost:8080",
        "interval": "10s",
        "timeout": "1s"
      },
      {
        "id": "http",
        "name": "HTTP on port 8080",
        "http": "http://localhost:8080",
        "interval": "30s",
        "timeout": "1s"
      },
      {
        "id": "service",
        "name": "jenkins",
        "args": ["systemctl", "status", "jenkins"],
        "interval": "60s"
      }
    ]
  }
}
EOF

consul reload