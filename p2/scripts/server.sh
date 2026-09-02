#!/bin/bash
# Part 2, the single machine: installs K3s in server mode, keeping Traefik
# because it is the Ingress controller the three applications route through.
set -e

# Which interface carries the private IP Vagrant assigned? Modern distributions
# use predictable names (enp0s8, ...) where older ones use eth1, so look it up
# rather than hardcoding it.
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')
echo "==> Private network: $NODE_IP on $IFACE"

# --node-ip / --flannel-iface keep the cluster on the private network instead
# of the NAT interface Vagrant uses for SSH. Traefik and servicelb stay on:
# together they put the Ingress on port 80 of the node.
echo "==> Installing K3s server"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=$NODE_IP \
  --flannel-iface=$IFACE \
  --write-kubeconfig-mode 644 \
  --disable metrics-server \
  --disable local-storage" sh -

# K3s ships its own kubectl, but the subject asks for kubectl explicitly
echo "==> Installing kubectl"
VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$VERSION/bin/linux/$(dpkg --print-architecture)/kubectl"
chmod +x /usr/local/bin/kubectl

# kubectl reads ~/.kube/config by default, so `vagrant ssh -c "kubectl ..."`
# works with no environment set up
echo "==> Giving the vagrant user a kubeconfig"
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "==> Waiting for the node to be ready"
kubectl wait --for=condition=Ready nodes --all --timeout=180s

# K3s deploys Traefik in the background, so the Deployment may not exist yet
echo "==> Waiting for Traefik"
while ! kubectl -n kube-system get deployment traefik >/dev/null 2>&1; do
  sleep 2
done
kubectl -n kube-system rollout status deployment/traefik --timeout=300s

kubectl get nodes -o wide
