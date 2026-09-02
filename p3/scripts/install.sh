#!/bin/bash
# Installs everything Part 3 needs: docker, kubectl and k3d.
set -e

# Re-run ourselves with sudo if we are not root
[ "$(id -u)" = "0" ] || exec sudo "$0" "$@"

USER_NAME=${SUDO_USER:-vagrant}
ARCH=$(dpkg --print-architecture)

echo "==> Installing base packages"
apt-get update -qq
apt-get install -y -qq curl git

echo "==> Installing docker"
command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh
systemctl enable --now docker
usermod -aG docker "$USER_NAME" || true

echo "==> Installing kubectl"
if ! command -v kubectl >/dev/null; then
  VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
  curl -sLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$VERSION/bin/linux/$ARCH/kubectl"
  chmod +x /usr/local/bin/kubectl
fi

echo "==> Installing k3d"
command -v k3d >/dev/null || \
  curl -sL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo
echo "Done. Run 'newgrp docker' (or log out and back in) so docker works without sudo."
