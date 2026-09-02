#!/bin/bash
# K3s in agent mode, joining the server.
set -e

# The interface carrying the private IP
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')
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

echo "==> Worker joined. Check with: vagrant ssh aelyakouS -c 'kubectl get nodes'"
