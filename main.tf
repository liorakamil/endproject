#provider "aws" {
#  version = ">= 2.28.1"
#  region  = var.region
#}

#data "aws_availability_zones" "available" {
#}

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
    "kubernetes.io/cluster/eks-cluster-flask" = "shared"
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    Name = "flask private subnets"
    "kubernetes.io/cluster/eks-cluster-flask" = "shared"
    "kubernetes.io/role/internal-elb" = 1
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

#resource "aws_security_group" "jenkins" {
#  name = local.jenkins_default_name
#  description = "Allow Jenkins inbound traffic"
#  vpc_id = module.vpc.vpc_id

#  egress {
#   from_port   = 0
#   to_port     = 0
#   protocol    = "-1"
#   cidr_blocks = ["0.0.0.0/0"]
# }

# egress {
#   from_port   = 22
#   to_port     = 22
#   protocol    = "tcp"
#   cidr_blocks = ["10.0.0.0/24"]
# }

#  ingress {
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    self        = true
#    description = "Allow all inside security group"
#  }

#  ingress {
#    from_port = 443
#    to_port = 443
#    protocol = "tcp"
#    cidr_blocks = [var.ip]
#    cidr_blocks = ["0.0.0.0/0"]
#  }

#  ingress {
#    from_port = 8080
#    to_port = 8080
#    protocol = "tcp"
#    cidr_blocks = [var.ip]
#  }

#  ingress {
#    from_port = 5000
#    to_port = 5000
#    protocol = "tcp"
#    cidr_blocks = [var.ip]
#  }

#  ingress {
#    from_port = 22
#    to_port = 22
#    protocol = "tcp"
#    cidr_blocks = [var.ip]
#    description = "Allow ssh from my ip"
#  }

#  ingress {
#    from_port = 2375
#    to_port = 2375
#    protocol = "tcp"
#    cidr_blocks = [var.ip]
#  }

#  tags = {
#    Name = local.jenkins_default_name
#  }
#}

resource "aws_db_instance" "mysql_server" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t2.micro"
  name                 = "users"
  username             = var.mysql_username
  password             = var.mysql_password
  port                 = var.port
  parameter_group_name = "default.mysql8.0"
  vpc_security_group_ids = [aws_security_group.jenkins-sg.id]
  multi_az             = false
  db_subnet_group_name   = aws_db_subnet_group.mysqldb.name
  skip_final_snapshot  = true
  apply_immediately = true

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

resource "aws_iam_role" "deploy-app" {
  name = "eks-cluster-deploy-app"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "deploy-app-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.deploy-app.name
}

resource "aws_iam_role_policy_attachment" "deploy-app-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.deploy-app.name
}

resource "aws_iam_policy" "eks-policy" {
  name        = "eks-policy"
  description = "EC2 access to EKS cluster"
  policy      = file("${path.module}/templates/policies/eks-describe.json")
}

resource "aws_iam_role_policy_attachment" "deploy-app-EC2EKSAccess" {
  policy_arn = aws_iam_policy.eks-policy.arn
  role       = aws_iam_role.deploy-app.name
}

resource "aws_iam_policy" "ekslb-policy" {
  name        = "eksLoadBalancer-policy"
  description = "EKS Load Balancer policy"
  policy      = file("${path.module}/templates/policies/eks-loadbalancer.json")
}

resource "aws_iam_role_policy_attachment" "deploy-app-eksLoadBalancer" {
  policy_arn = aws_iam_policy.ekslb-policy.arn
  role       = aws_iam_role.deploy-app.name
}

# Create the instance profile
resource "aws_iam_instance_profile" "deploy-app" {
  name  = "eks-cluster-deploy-app"
  role = aws_iam_role.deploy-app.name
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

data "aws_secretsmanager_secret" "flask-rds" {
  name = "flask-rds"
}

data "aws_secretsmanager_secret_version" "flask-rds" {
  secret_id = data.aws_secretsmanager_secret.flask-rds.id
}

output "secret_key1_USER" {
  value = jsondecode(data.aws_secretsmanager_secret_version.flask-rds.secret_string)["USER"]
}

output "secret_key2_PASSWORD" {
  value = jsondecode(data.aws_secretsmanager_secret_version.flask-rds.secret_string)["PASSWORD"]
}

#output "jenkins_master" {
#  value = ["${aws_instance.jenkins_master.public_ip}"]
#}