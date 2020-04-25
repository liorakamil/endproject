locals {
  monitoring_name = "monitoring"
}

#Monitoring Security Group
resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-sg"
  description = "Security group for monitoring server"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow ICMP from control host IP
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = [var.ip]
  }

  # Allow all SSH External
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [var.ip]
  }

  # Allow all traffic to HTTP port 3000
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "TCP"
    cidr_blocks = [var.ip]
  }

  # Allow all traffic to HTTP port 9090
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "TCP"
    cidr_blocks = [var.ip]
  }
}

data "template_file" "docker-monitoring" {
  template = file("${path.module}/templates/docker.sh.tpl")
}

data "template_file" "fluentd-monitoring" {
  template = file("${path.module}/templates/fluentd.sh.tpl")
  vars = {
    elasticsearch_user = var.elastic_user
    elasticsearch_password = var.elastic_password
    elasticsearch_host = aws_instance.logging.private_ip
  }
}

data "template_file" "consul-monitoring" {
  template = file("${path.module}/templates/consul.sh.tpl")

  vars = {
    consul_version = var.consul_version
    config = <<EOF
       "node_name": "monitoring",
       "enable_script_checks": true,
       "server": false
      EOF
  }
}

data "template_file" "monitoring" {
  template = file("${path.module}/templates/monitoring.sh.tpl")
  vars = {
    HOSTNAME = "grafana1"
    consul_server = aws_instance.consul_server[0].private_ip
  }
}

# Create the user-data for monitoring
data "template_cloudinit_config" "monitoring" {
  part {
    content = data.template_file.fluentd-monitoring.rendered
  }
  part {
    content = data.template_file.docker-monitoring.rendered
  }
  part {
    content = data.template_file.consul-monitoring.rendered
  }  
  part {
    content = data.template_file.monitoring.rendered
  }
}

# Allocate the EC2 monitoring instance
resource "aws_instance" "monitoring" {
  ami = "ami-07d0cf3af28718ef8"
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = aws_key_pair.jenkins_key.key_name


  tags = {
    Name = "monitring"
  }
  
  iam_instance_profile   = aws_iam_instance_profile.deploy-app.name
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id, aws_security_group.opsschool_consul.id]

  connection {
    host = aws_instance.monitoring.public_ip
    user = "ubuntu"
    private_key = tls_private_key.jenkins_key.private_key_pem
  }
  
  user_data = data.template_cloudinit_config.monitoring.rendered
}

output "monitor_server_public_ip" {
  value = join(",", aws_instance.monitoring.*.public_ip)
}

output "monitoring" {
  value = ["${aws_instance.monitoring.public_ip}"]
}
