#!/usr/bin/env bash
set +e

echo "Updating kubectl auth to EKS"
aws eks --region us-east-1 update-kubeconfig --name eks-cluster-flask

kubectl create namespace prometheus
helm upgrade -i prometheus stable/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="gp2" \
    --set server.persistentVolume.storageClass="gp2"

kubectl create namespace grafana
helm upgrade -i grafana stable/grafana \
    --namespace grafana \
    --set persistence.storageClassName="gp2" \
    --set adminPassword='EKS!sAWSome' \
    --set datasources."datasources\.yaml".apiVersion=1 \
    --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
    --set datasources."datasources\.yaml".datasources[0].type=prometheus \
    --set datasources."datasources\.yaml".datasources[0].url=http://prometheus-server.prometheus.svc.cluster.local \
    --set datasources."datasources\.yaml".datasources[0].access=proxy \
    --set datasources."datasources\.yaml".datasources[0].isDefault=true \
    --set service.type=NodePort

helm repo add kiwigrid https://kiwigrid.github.io
helm upgrade -i fluentd kiwigrid/fluentd-elasticsearch \
    --set elasticsearch.auth.enabled=true \
    --set elasticsearch.auth.user=elastic \
    --set elasticsearch.auth.password=changeme \
    --set elasticsearch.hosts={"elasticsearch:9200"}

#install consul on eks
#helm upgrade -i hashicorp ./consul-helm -f ./consul-helm/config.yaml