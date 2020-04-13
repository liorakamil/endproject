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
resource "aws_instance" "consul_client" {
  ami                    = lookup(var.ami, var.region)
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.jenkins_key.key_name
  count                  = 1

  vpc_security_group_ids = [aws_security_group.opsschool_consul.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  
  tags = {
    Name = "consul_client${count.index + 1}"
  }
  user_data              = file("consul-agent.sh")

  connection {
    type = "ssh"
    host = "self.public_ip"
    private_key = tls_private_key.jenkins_key.private_key_pem
    user = "ubuntu"
  }
}

output "consul_servers" {
  value = ["${aws_instance.consul_server.*.public_ip}"]
}

output "clients" {
  value = ["${aws_instance.consul_client.*.public_ip}"]
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