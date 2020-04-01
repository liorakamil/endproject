# Create the user-data for the Consul server
data "template_file" "consul_server" {
  count    = var.servers
  template = file("${path.module}/templates/consul.sh.tpl")

  vars = {
    consul_version = var.consul_version
    node_exporter_version = var.node_exporter_version
    prometheus_dir = var.prometheus_dir
    config = <<EOF
  "node_name": "consul-server-${count.index+1}",
  "server": true,
  "bootstrap_expect": 3,
  "ui": true,
  "client_addr": "0.0.0.0",
  "telemetry": {
    "prometheus_retention_time": "10m"
  }
EOF
  }
}

data "template_file" "consul_client" {
  count    = var.clients
  template = file("${path.module}/templates/consul.sh.tpl")

  vars = {
      consul_version = var.consul_version
      node_exporter_version = var.node_exporter_version
      prometheus_dir = var.prometheus_dir
      config = <<EOF
       "node_name": "consul-client-${count.index+1}",
       "enable_script_checks": true,
       "server": false
      EOF
  }
}

data "template_file" "webserver" {
  count    = var.clients
  template = file("${path.module}/templates/webserver.sh.tpl")

  vars = {
      apache_exporter_version = var.apache_exporter_version
      prometheus_dir = var.prometheus_dir
  }
}

# Create the user-data for the Consul agent
data "template_cloudinit_config" "consul_client" {
  count    = var.clients
  part {
    content = element(data.template_file.consul_client.*.rendered, count.index)

  }
  part {
    content = element(data.template_file.webserver.*.rendered, count.index)
  }
}

# Create the Consul cluster
resource "aws_instance" "consul_server" {
  count = var.servers

  ami           = lookup(var.ami, var.region)
  instance_type = "t2.micro"
  key_name      = aws_key_pair.jenkins_key.key_name
  subnet_id     = module.vpc.public_subnets[0]

  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  vpc_security_group_ids = [aws_security_group.opsschool_consul.id]

  tags = {
    Name = "consul-server-${count.index+1}"
    consul_server = "true"
  }

  user_data = element(data.template_file.consul_server.*.rendered, count.index)
}

resource "aws_instance" "consul_client" {
  count = var.clients

  ami           = lookup(var.ami, var.region)
  instance_type = "t2.micro"
  key_name      = aws_key_pair.jenkins_key.key_name
  subnet_id     = module.vpc.public_subnets[0]

  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  vpc_security_group_ids = [aws_security_group.opsschool_consul.id]

  tags = {
    Name = "consul-client-${count.index+1}"
  }

  user_data = element(data.template_cloudinit_config.consul_client.*.rendered, count.index)
}

output "servers" {
  value = ["${aws_instance.consul_server.*.public_ip}"]
}

output "clients" {
  value = ["${aws_instance.consul_client.*.public_ip}"]
}
