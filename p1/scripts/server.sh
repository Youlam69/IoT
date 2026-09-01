#!/bin/bash
# Installs K3s in server (controller) mode.
set -e

# The private-network interface, found from the IP Vagrant put on it: modern
# distributions use predictable names (enp0s8, ...) where older ones use eth1.
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')
echo "==> Private network: $NODE_IP on $IFACE"

# Drop a token left over from a previous cluster
rm -f /shared/node-token

echo "==> Installing K3s server"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=$NODE_IP \
  --flannel-iface=$IFACE \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable metrics-server \
  --disable servicelb" sh -

echo "==> Installing kubectl"
VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$VERSION/bin/linux/$(dpkg --print-architecture)/kubectl"
chmod +x /usr/local/bin/kubectl

echo "==> Configuring kubectl for the vagrant user"
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
echo 'export KUBECONFIG=/home/vagrant/.kube/config' > /etc/profile.d/k3s.sh

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "==> Waiting for the node to be ready"
kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo "==> Sharing the token with the worker"
cp /var/lib/rancher/k3s/server/node-token /shared/node-token

kubectl get nodes -o wide
