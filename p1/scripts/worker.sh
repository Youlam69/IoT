#!/bin/bash
# Installs K3s in agent (worker) mode and joins the server.
set -e

# Private network interface on bento/ubuntu-24.04
IFACE=eth1
echo "==> Private network: $NODE_IP on $IFACE"

echo "==> Waiting for the server to share its token"
while [ ! -s /shared/node-token ]; do
  sleep 2
done

echo "==> Installing K3s agent"
curl -sfL https://get.k3s.io | \
  K3S_URL="https://$SERVER_IP:6443" \
  K3S_TOKEN="$(cat /shared/node-token)" \
  INSTALL_K3S_EXEC="agent --node-ip=$NODE_IP --flannel-iface=$IFACE" sh -

echo "==> Installing kubectl"
VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$VERSION/bin/linux/$(dpkg --print-architecture)/kubectl"
chmod +x /usr/local/bin/kubectl

echo "==> Worker joined. Check with: vagrant ssh aelyakouS -c 'kubectl get nodes'"
