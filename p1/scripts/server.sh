#!/bin/bash
# Part 1, machine 1: installs K3s in server (controller) mode and publishes
# the join token so the worker can pick it up from the shared folder.
set -e

# Which interface carries the private IP Vagrant assigned? Modern distributions
# use predictable names (enp0s8, ...) where older ones use eth1, so look it up
# rather than hardcoding it.
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')
echo "==> Private network: $NODE_IP on $IFACE"

# A token from a previous cluster would let the worker join the wrong one
rm -f /shared/node-token

# --node-ip / --flannel-iface keep the cluster on the private network instead
# of the NAT interface Vagrant uses for SSH. Part 1 needs no ingress or load
# balancer, so traefik, servicelb and metrics-server are all turned off.
echo "==> Installing K3s server"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=$NODE_IP \
  --flannel-iface=$IFACE \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable metrics-server \
  --disable servicelb" sh -

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

echo "==> Sharing the join token with the worker"
cp /var/lib/rancher/k3s/server/node-token /shared/node-token

kubectl get nodes -o wide
