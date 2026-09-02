#!/bin/bash
# Deploys the three applications and the Ingress.
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "==> Applying the manifests"
kubectl apply -f /vagrant/confs/

for app in app-one app-two app-three; do
  kubectl rollout status deployment/$app --timeout=180s
done

kubectl get deployments,services,ingress
