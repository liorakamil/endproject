#provider "aws" {
#  version = "~> 2.0"
#  region  = var.region
#}

data "aws_availability_zones" "available" {
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = "eks-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = var.vpc_private_subnets
  public_subnets       = var.vpc_public_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false

  tags = {
    Name = "finproject VPC"
  }

  public_subnet_tags = {
    Name = "flask public subnets"
  }

  private_subnet_tags = {
    Name = "flask private subnets"
  }
} 

locals {
  jenkins_default_name = "jenkins"
  jenkins_home = "/home/ubuntu/jenkins_home"
  jenkins_home_mount = "${local.jenkins_home}:/var/jenkins_home"
  docker_sock_mount = "/var/run/docker.sock:/var/run/docker.sock"
  java_opts = "JAVA_OPTS='-Djenkins.install.runSetupWizard=false'"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "jenkins" {
  name = local.jenkins_default_name
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
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ssh from the world"
  }

  ingress {
    from_port = 2375
    to_port = 2375
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.jenkins_default_name
  }
}

resource "aws_instance" "jenkins_master" {
  ami = "ami-07d0cf3af28718ef8"
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name = aws_key_pair.jenkins_key.key_name


  tags = {
    Name = "Jenkins Master flask"
  }

  vpc_security_group_ids = [aws_security_group.jenkins.id]

  connection {
    host = aws_instance.jenkins_master.public_ip
    user = "ubuntu"
    private_key = tls_private_key.jenkins_key.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt install docker.io -y",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo usermod -aG docker ubuntu",
      "mkdir -p ${local.jenkins_home}",
      "sudo chown -R 1000:1000 ${local.jenkins_home}"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo docker run -d -p 8080:8080 -p 50000:50000 -v ${local.jenkins_home_mount} -v ${local.docker_sock_mount} --env ${local.java_opts} liorakamil/jenkins:withpins"
    ]
  }
}

resource "aws_instance" "jenkins_agent" {
  ami = "ami-00068cd7555f543d5"
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name = aws_key_pair.jenkins_key.key_name

  tags = {
    Name = "Jenkins Agent flask"
  }

  vpc_security_group_ids = [aws_security_group.jenkins.id]

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
  EOF
}

resource "aws_db_instance" "mysql_server" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t2.micro"
  name                 = "mysqldb"
  username             = var.username
  password             = var.password
  port                 = var.port
  parameter_group_name = "default.mysql8.0"
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  multi_az             = true
  db_subnet_group_name   = aws_db_subnet_group.mysqldb.name
  skip_final_snapshot  = true
  
  tags = {
    Name       = "flask-mysql"
  }
}

resource "aws_db_subnet_group" "mysqldb" {
  name        = "flask-mysql"
  subnet_ids  = module.vpc.private_subnets

  tags = {
    Name       = "flask-mysql"
  }
}

resource "aws_iam_user" "user" {
  name = "ep-project"
}

resource "aws_iam_policy" "policy" {
  name        = "end-project-policy"
  description = "user admin policy - AmazonEKSClusterPolicy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:UpdateAutoScalingGroup",
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateRoute",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteRoute",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteVolume",
                "ec2:DescribeInstances",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumesModifications",
                "ec2:DescribeVpcs",
                "ec2:DescribeDhcpOptions",
                "ec2:DetachVolume",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifyVolume",
                "ec2:RevokeSecurityGroupIngress",
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
                "elasticloadbalancing:AttachLoadBalancerToSubnets",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateLoadBalancerListeners",
                "elasticloadbalancing:CreateLoadBalancerPolicy",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DeleteLoadBalancerListeners",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeLoadBalancerPolicies",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DetachLoadBalancerFromSubnets",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
                "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "mid-project-attach" {
  user       = aws_iam_user.user.name
  policy_arn = aws_iam_policy.policy.arn
}
