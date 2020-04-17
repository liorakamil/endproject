locals {
  jenkins_name = "jenkins"
}

resource "aws_security_group" "jenkins-sg" {
  name = "jenkins-sg"
  description = "Allow Jenkins inbound traffic"
  vpc_id = module.vpc.vpc_id

  egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }

 egress {
   from_port   = 22
   to_port     = 22
   protocol    = "tcp"
   cidr_blocks = ["10.0.0.0/24"]
 }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all inside security group"
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [var.ip]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = [var.ip]
  }

  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = [var.ip]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.ip]
    description = "Allow ssh from my ip"
  }

  tags = {
    Name = local.jenkins_name
  }
}

data "template_file" "docker" {
  template = file("${path.module}/templates/docker.sh.tpl")
}

data "template_file" "fluentd" {
  template = file("${path.module}/templates/fluentd.sh.tpl")
  vars = {
    elasticsearch_user = var.elastic_user
    elasticsearch_password = var.elastic_password
    elasticsearch_host = aws_instance.logging.private_ip
  }
}

data "template_file" "consul" {
  template = file("${path.module}/templates/consul.sh.tpl")

  vars = {
    consul_version = var.consul_version
    config = <<EOF
       "node_name": "jenkins",
       "enable_script_checks": true,
       "server": false
      EOF
  }
}

data "template_file" "prometheus" {
  template = file("${path.module}/templates/prometheus.sh.tpl")
  vars = {
    node_exporter_version = var.node_exporter_version
    promcol_version = var.promcol_version
    prometheus_conf_dir = var.prometheus_conf_dir
    prometheus_dir = var.prometheus_dir
    prometheus_host = "localhost"
  }
}

data "template_file" "jenkins" {
  template = file("${path.module}/templates/jenkins.sh.tpl")
}

# Create the user-data for Jekins
data "template_cloudinit_config" "jenkins" {
  part {
    content = data.template_file.fluentd.rendered
  }
  part {
    content = data.template_file.docker.rendered
  }
  part {
    content = data.template_file.consul.rendered
  }  
  part {
    content = data.template_file.prometheus.rendered
  }
  part {
    content = data.template_file.jenkins.rendered
  }
}

resource "aws_instance" "jenkins_master_instance" {
  ami = "ami-07d0cf3af28718ef8"
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = aws_key_pair.jenkins_key.key_name


  tags = {
    Name = "Jenkins Master"
  }
  
  iam_instance_profile   = aws_iam_instance_profile.deploy-app.name
  vpc_security_group_ids = [aws_security_group.jenkins-sg.id, aws_security_group.opsschool_consul.id]

  connection {
    host = aws_instance.jenkins_master_instance.public_ip
    user = "ubuntu"
    private_key = tls_private_key.jenkins_key.private_key_pem
  }
  
  user_data = data.template_cloudinit_config.jenkins.rendered
}

resource "aws_instance" "jenkins_agent" {
  ami = "ami-00068cd7555f543d5"
  instance_type = "t2.micro"
  subnet_id     = module.vpc.private_subnets[0]
  key_name = aws_key_pair.jenkins_key.key_name

  tags = {
    Name = "Jenkins Agent"
  }

  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.deploy-app.name

  connection {
    host = aws_instance.jenkins_agent.public_ip
    user = "ec2-user"
    private_key = tls_private_key.jenkins_key.private_key_pem
  }
   
  user_data = <<-EOF
  #! /bin/bash
  sudo yum update -y
  sudo yum install java-1.8.0 -y
  sudo alternatives --install /usr/bin/java java /usr/java/latest/bin/java 1
  sudo alternatives --config java
  sudo yum install docker git -y
  sudo service docker start
  sudo usermod -aG docker ec2-user
  curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
  EOF
}
