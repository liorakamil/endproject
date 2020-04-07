variable "region" {
  description = "AWS region for VMs"
  default = "us-east-1"
}

#variable "availability_zone_names" {
#  type    = list(string)
#  default = ["us-east-1"]
#}

variable "vpc_private_subnets" {
    type    = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "vpc_public_subnets" {
    type    = list(string)
    default = ["10.0.40.0/24", "10.0.50.0/24"]
}
#consul
variable "servers" {
  description = "The number of consul servers."
  default = 3
}

variable "clients" {
  description = "The number of consul client instances"
  default = 1
}

variable "consul_version" {
  description = "The version of Consul to install (server and client)."
  default     = "1.4.0"
}

variable "key_name" {
  description = "name of ssh key to attach to hosts"
  default = "radzi"
}

variable "ami" {
  description = "ami to use - based on region"
  default = {
    "us-east-1" = "ami-04b9e92b5572fa0d1"
    "us-east-2" = "ami-0d5d9d301c853a04a"
  }
}

variable "prometheus_dir" {
  description = "directory for prometheus binaries"
  default = "/opt/prometheus"
}

variable "prometheus_conf_dir" {
  description = "directory for prometheus configuration"
  default = "/etc/prometheus"
}

variable "promcol_version" {
  description = "Prometheus Collector version"
  default = "2.16.0"
}

variable "node_exporter_version" {
  description = "Node Exporter version"
  default = "0.18.1"
}

variable "apache_exporter_version" {
  description = "Apache Exporter version"
  default = "0.7.0"
}

#monitoring
variable "monitor_instance_type" {
  default = "t2.small"
}

variable "monitor_servers" {
  default = "1"
}

variable "owner" {
  default = "Monitoring"
}

#RDS parameters
variable "mysql_username" {
  type        = string
  description = "Username for the master DB user."
}

#variable "mysql_dbname" {
#  description = "The Database name inside your RDS"
#}

variable "mysql_password" {
  type        = string
  description = "Password for the master DB user."
}

variable "port" {
  default     = 3306
  type        = string
  description = "The port on which the DB accepts connections."
}
#variable "vpc_id" {
#  default = "vpc-08c59372"
#}

variable "ip" {
  default = ""
  description = "my private ip"
}

#variable "flask-rds" {
#  default = {
#  key1 = "user"
#   key2 = "password"
# }

#  type = map(string)
#}