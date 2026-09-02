#!/bin/bash
# Deploys the three applications and the Ingress that routes between them.
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "==> Applying the manifests"
kubectl apply -f /vagrant/confs/

for app in app-one app-two app-three; do
  kubectl rollout status deployment/$app --timeout=180s
done

echo "==> Testing the routes"
sleep 5
for host in app1.com app2.com other.com; do
  echo "  $host -> $(curl -s -H "Host: $host" "http://$NODE_IP/" | grep -o '<h1>.*</h1>')"
done

kubectl get deployments,services,ingress
