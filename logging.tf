resource "aws_security_group" "sg_logging" {
  name = "sg_logging"
  description = "Allow logging inbound traffic"
  vpc_id = module.vpc.vpc_id

  egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all inside security group"
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.ip]
    description = "Allow ssh from the world"
  }

  ingress {
    from_port = 5601
    to_port = 5601
    protocol = "tcp"
    cidr_blocks = [var.ip]
    description = "Allow kibana from the world"
  }

  # Allow fluentd from eks to elasticsearch 
  ingress {  
    from_port = 9200
    to_port = 9300
    protocol = "tcp"
    security_groups = [aws_security_group.worker_group_mgmt_one.id]
    cidr_blocks = [var.ip, "10.0.0.0/16"]
  }

  tags = {
    Name = "sg_logging"
  }
}

data "template_file" "docker-logging" {
  template = file("${path.module}/templates/docker.sh.tpl")
}

data "template_file" "consul-logging" {
  template = file("${path.module}/templates/consul.sh.tpl")

  vars = {
    consul_version = var.consul_version
    config = <<EOF
       "node_name": "logging",
       "enable_script_checks": true,
       "server": false
      EOF
  }
}

data "template_file" "logging" {
  template = file("${path.module}/templates/logging.sh.tpl")
  vars = {
    ELK_VERSION = "7.6.0"
  }
}

data "template_file" "fluentd-server" {
  template = file("${path.module}/templates/fluentd.sh.tpl")
  vars = {
    elasticsearch_user = var.elastic_user
    elasticsearch_password = var.elastic_password
    elasticsearch_host = "localhost"
  }
}

# Create the user-data for logging
data "template_cloudinit_config" "logging" {
  part {
    content = data.template_file.docker-logging.rendered
  }
  part {
    content = data.template_file.consul-logging.rendered
  }  
  part {
    content = data.template_file.logging.rendered
  }
  part {
    content = data.template_file.fluentd-server.rendered
  }
}

resource "aws_instance" "logging_new" {
  ami                    = lookup(var.ami, var.region)
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.jenkins_key.key_name
#  count                  = 1

  vpc_security_group_ids = [aws_security_group.opsschool_consul.id, aws_security_group.sg_logging.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  
  tags = {
    Name = "logging-new"
  }
#  user_data              = file("consul-agent.sh")

  connection {
    type = "ssh"
    host = aws_instance.logging_new.public_ip
    private_key = tls_private_key.jenkins_key.private_key_pem
    user = "ubuntu"
  }
}

output "logging_new" {
  value = ["${aws_instance.logging_new.public_ip}"]
}


