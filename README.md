# Opsschool end-project: The Elephant

This repo build a small prod like environment, to support deployment of a simple Flask application in an automated fashion.
Environemt include: 
-Simple Flask application  
-Deployment of the apllication on kubernetes
-Consul cluster
-CI/CD cluster with jenkins
-Logging cluster deploying EFK
-Monitoring with prometheus visualized by grafana
-Mysql server - RDS

The Application:
A webpage with two text fields: name, email. with entering the submit button, all data is stored in a mysql database. The data stored can be presented and retrieved on the webpage. 

## Built With
Terraform - infastractures
AWS - cloud provider

## Getting Started: 
1. Clone repo: endproject

### Deployment
1. Init Terraform
2. Run terraform plan -out main.tfplan, "terraform apply"
3. Run eks-init.sh

## Versioning
Terraform 0.12
Helm 3
Consul 1.4.0 
mysql 8.0

## Acknowledgments
1. The amazing team of Opsschool 5
https://github.com/ops-school
https://github.com/MadDamDam/opsschool-monitoring
2. kiwigrid https://kiwigrid.github.io



