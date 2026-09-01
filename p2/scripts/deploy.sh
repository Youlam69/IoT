#!/bin/bash
# Deploys the three applications and the Ingress that routes between them.
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "==> Applying the manifests"
kubectl apply -f /vagrant/confs/

echo "==> Waiting for the applications"
for app in app-one app-two app-three; do
  kubectl rollout status deployment/$app --timeout=180s
done

# Lets you use the hostnames from inside the VM too
echo "==> Adding app1.com and app2.com to /etc/hosts"
sed -i '/# iot/d' /etc/hosts
echo "$NODE_IP app1.com app2.com # iot" >> /etc/hosts

echo "==> Testing the routes"
sleep 5
for host in app1.com app2.com other.com; do
  page=$(curl -s -H "Host: $host" "http://$NODE_IP/" | grep -o '<h1>.*</h1>' || true)
  echo "  Host: $host -> ${page:-no response}"
done

kubectl get deployments,services,ingress
