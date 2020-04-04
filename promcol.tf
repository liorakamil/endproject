data "template_file" "consul_promcol" {
  template = file("${path.module}/templates/consul.sh.tpl")

  vars = {
      consul_version = var.consul_version
      node_exporter_version = var.node_exporter_version
      prometheus_dir = var.prometheus_dir
      config = <<EOF
       "node_name": "promcol",
       "enable_script_checks": true,
       "server": false
      EOF
  }
}

data "template_file" "promcol" {
  template = file("${path.module}/templates/promcol.sh.tpl")

  vars = {
      promcol_version = var.promcol_version
      prometheus_conf_dir = var.prometheus_conf_dir
      prometheus_dir = var.prometheus_dir
  }
}

# Create the user-data for the Consul agent
data "template_cloudinit_config" "promcol" {
  part {
    content = data.template_file.consul_promcol.rendered

  }
  part {
    content = data.template_file.promcol.rendered
  }
}

resource "aws_instance" "promcol" {
  ami           = lookup(var.ami, var.region)
  instance_type = "t2.micro"
  key_name      = aws_key_pair.jenkins_key.key_name
  subnet_id     = module.vpc.public_subnets[0]

  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  vpc_security_group_ids = [aws_security_group.jenkins.id]

  tags = {
    Name = "promcol"
  }

  user_data = data.template_cloudinit_config.promcol.rendered
}

output "promcol" {
  value = ["${aws_instance.promcol.public_ip}"]
}

