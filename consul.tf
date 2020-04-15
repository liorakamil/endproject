resource "aws_instance" "consul_server" {
  ami                    = lookup(var.ami, var.region)
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.jenkins_key.key_name
  count                  = 3

  vpc_security_group_ids = [aws_security_group.opsschool_consul.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  
  tags = {
    Name = "consul-server${count.index + 1}"
    consul_server = true
  }
  user_data              = file("consul-server.sh")

  connection {
    type = "ssh"
    host = "self.public_ip"
    private_key = tls_private_key.jenkins_key.private_key_pem
    user = "ubuntu"
  }
}

resource "aws_security_group" "logging_sg" {
  name = "logging-sg"
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
#   cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ssh from the world"
  }

  ingress {
    from_port = 5601
    to_port = 5601
    protocol = "tcp"
    cidr_blocks = [var.ip]
    description = "Allow kibana from the world"
  }

  # Allow filebeat from eks to elasticsearch 
  ingress {  
    from_port = 9200
    to_port = 9200
    protocol = "tcp"
    security_groups = [aws_security_group.worker_group_mgmt_one.id]
  }

  tags = {
    Name = "logging-sg"
  }
}

resource "aws_instance" "logging" {
  ami                    = lookup(var.ami, var.region)
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.jenkins_key.key_name
#  count                  = 1

  vpc_security_group_ids = [aws_security_group.opsschool_consul.id, aws_security_group.logging_sg.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  
  tags = {
    Name = "logging"
  }
  user_data              = file("consul-agent.sh")

  connection {
    type = "ssh"
    host = aws_instance.logging.public_ip
    private_key = tls_private_key.jenkins_key.private_key_pem
    user = "ubuntu"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt install docker.io -y",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu",
      "sudo curl -L \"https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose"
    ]
  }
}

output "consul_servers" {
  value = ["${aws_instance.consul_server.*.public_ip}"]
}

output "logging" {
  value = ["${aws_instance.logging.*.public_ip}"]
}

#data "aws_ami" "ubuntu" {
#  most_recent = true

#  filter {
#    name   = "name"
#    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
#  }

#  filter {
#    name   = "virtualization-type"
#    values = ["hvm"]
#  }

#  owners = ["099720109477"] # Canonical
#}