node {
 def customImage = ""
 def shortCommit = ""
 stage("pull code") {
     checkout scm
     shortCommit = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
 }

 stage("build docker") {
    customImage = docker.build("liorakamil/endproject:${env.BUILD_ID}")
    withDockerRegistry(credentialsId: 'dockerhub') {
        customImage.push()
    }
 }

 stage("verify dockers") {
  sh "docker images"
 }
 stage('Apply Kubernetes files') {
    withAWS(region: 'us-east-1') {
sh """
aws eks update-kubeconfig --name eks-cluster-flask

cat <<EOF | kubectl apply -f -
apiVersion: v1      # for versions before 1.9.0 use apps/v1beta2
kind: Service
metadata:
  name: flask-service
  labels:
    app: flask
spec:
  type: LoadBalancer
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5000
  selector:
    app: flask
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-deployment
spec:
  selector:
    matchLabels:
      app: flask
  replicas: 2 # tells deployment to run 2 pods matching the template
  template:
    metadata:
      labels:
        app: flask
    spec:
      containers:
      - name: flask
        image: liorakamil/endproject:${shortCommit}
        ports:
        - containerPort: 5000
        env:
          - name: MYSQL_HOST
            valueFrom:
              secretKeyRef:
                name: db-secret
                key: host
          - name: MYSQL_USER
            valueFrom:
              secretKeyRef:
                name: db-secret
                key: username
          - name: MYSQL_PASSWORD
            valueFrom:
              secretKeyRef:
                name: db-secret
                key: password            
EOF
"""
    }
  }
}