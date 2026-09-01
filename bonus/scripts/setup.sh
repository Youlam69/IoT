#!/bin/bash
# Builds the Part 3 lab on top of a GitLab running inside the cluster.
# Run p3/scripts/install.sh first. GitLab needs ~8 GB of RAM and 10-20 minutes.
set -e

DIR=$(cd "$(dirname "$0")/../.." && pwd)

echo "==> Creating the k3d cluster (ports 80 and 443 published)"
k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx iot || \
  k3d cluster create --config "$DIR/bonus/confs/k3d-cluster.yaml"
kubectl config use-context k3d-iot

echo "==> Creating the argocd, dev and gitlab namespaces"
kubectl apply -f "$DIR/p3/confs/namespaces.yaml"
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing GitLab with Helm (go get a coffee)"
helm repo add gitlab https://charts.gitlab.io/
helm repo update gitlab
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --values "$DIR/bonus/confs/gitlab-values.yaml" \
  --timeout 30m --wait

echo "==> Installing Argo CD"
# --server-side is required: the ApplicationSet CRD is ~340 KB, and a plain
# client-side apply stores it in the last-applied-configuration annotation,
# which the API server caps at 256 KB.
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd patch configmap argocd-cm --patch-file "$DIR/p3/confs/argocd-cm-patch.yaml"
kubectl -n argocd rollout restart deployment/argocd-repo-server \
  statefulset/argocd-application-controller
kubectl -n argocd wait --for=condition=Available deployment --all --timeout=600s

echo "==> Adding gitlab.gitlab.local to /etc/hosts"
sudo sed -i '/# iot-bonus/d' /etc/hosts
echo "127.0.0.1 gitlab.gitlab.local registry.gitlab.local # iot-bonus" | sudo tee -a /etc/hosts

"$DIR/bonus/scripts/credentials.sh"

cat <<MSG
Now, once, by hand:

  1. Log into http://gitlab.gitlab.local as root and create a PUBLIC
     project named aelyakou-iot.

  2. Push the Part 3 manifests to it:
       cd $DIR/p3/app-repo
       git init -b main && git add deployment.yaml service.yaml
       git commit -m "playground v1"
       git remote add gitlab http://gitlab.gitlab.local/root/aelyakou-iot.git
       git push -u gitlab main

  3. Let Argo CD deploy it:
       kubectl apply -f $DIR/bonus/confs/application.yaml
MSG
