Opsschool end-project: 
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

Deployment:
1. Clone repo: endproject
2. Init Terraform and run: terraform plan.. followed by "terraform apply..."
3. Run eks-init.sh

Credits:
1. The amazing team of Opsschool 5 https://github.com/ops-school
2. kiwigrid https://kiwigrid.github.io


