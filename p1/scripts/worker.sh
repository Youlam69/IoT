#!/bin/bash
# Installs K3s in agent (worker) mode and joins the server.
set -e

# The private-network interface, found from the IP Vagrant put on it: modern
# distributions use predictable names (enp0s8, ...) where older ones use eth1.
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')
if [ -z "$IFACE" ]; then
  echo "ERROR: no interface carries $NODE_IP" >&2
  ip -o -4 addr show >&2
  exit 1
fi
echo "==> Private network: $NODE_IP on $IFACE"

echo "==> Waiting for the server to share its token"
for _ in $(seq 150); do
  [ -s /shared/node-token ] && break
  sleep 2
done
if [ ! -s /shared/node-token ]; then
  echo "ERROR: /shared/node-token never appeared. Bring the server up first:" >&2
  echo "       vagrant up aelyakouS" >&2
  exit 1
fi

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
