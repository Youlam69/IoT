#!/bin/bash
# Installs K3s in server mode, keeping Traefik as the Ingress controller.
set -e

# The interface holding the private IP (eth1 or enp0s8, depending on the box)
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')
echo "==> Private network: $NODE_IP on $IFACE"

# Pin K3s to the private network. Traefik and servicelb put the Ingress on port 80.
echo "==> Installing K3s server"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=$NODE_IP \
  --flannel-iface=$IFACE \
  --write-kubeconfig-mode 644 \
  --disable metrics-server \
  --disable local-storage" sh -

# The subject asks for kubectl explicitly
echo "==> Installing kubectl"
VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$VERSION/bin/linux/$(dpkg --print-architecture)/kubectl"
chmod +x /usr/local/bin/kubectl

# kubectl reads ~/.kube/config by default
echo "==> Giving the vagrant user a kubeconfig"
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "==> Waiting for the node to be ready"
kubectl wait --for=condition=Ready nodes --all --timeout=180s

# K3s deploys Traefik in the background
echo "==> Waiting for Traefik"
while ! kubectl -n kube-system get deployment traefik >/dev/null 2>&1; do
  sleep 2
done
kubectl -n kube-system rollout status deployment/traefik --timeout=300s

kubectl get nodes -o wide
