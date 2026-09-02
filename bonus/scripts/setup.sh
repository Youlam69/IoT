#!/bin/bash
# Part 3 on top of a GitLab running in the cluster. Run p3/scripts/install.sh
# first. GitLab needs ~8 GB of RAM and 10-20 minutes.
set -e

DIR=$(cd "$(dirname "$0")/../.." && pwd)

echo "==> Installing helm"
command -v helm >/dev/null || \
  curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash

# Published by k3d: localhost -> GitLab, :8080 -> Argo CD, :8888 -> the app
echo "==> Creating the k3d cluster"
# Single node on purpose: every extra node pulls its own copy of GitLab's
# ~5 GB of images, which is enough to fill the VM's disk.
k3d cluster list | grep -q '^iot ' || k3d cluster create iot \
  -p "80:80@loadbalancer" \
  -p "8080:30080@loadbalancer" \
  -p "8888:30888@loadbalancer" \
  --k3s-arg "--disable=metrics-server@server:*"
kubectl config use-context k3d-iot

echo "==> Creating the argocd, dev and gitlab namespaces"
kubectl apply -f "$DIR/p3/confs/namespaces.yaml"
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing GitLab with Helm (go get a coffee)"
helm repo add gitlab https://charts.gitlab.io/
helm repo update gitlab
# Pinned: chart 10.x dropped the bundled PostgreSQL, Redis and object storage
# and requires them as external services. 9.11.12 is the last self-contained one.
helm upgrade --install gitlab gitlab/gitlab --version 9.11.12 --namespace gitlab \
  --values "$DIR/bonus/confs/gitlab-values.yaml" --timeout 30m --wait

echo "==> Installing Argo CD"
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd patch configmap argocd-cm -p '{"data":{"timeout.reconciliation":"30s"}}'
kubectl -n argocd patch svc argocd-server \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"nodePort":30080}]}}'
kubectl -n argocd rollout restart deployment/argocd-repo-server \
  statefulset/argocd-application-controller
kubectl -n argocd wait --for=condition=Available deployment --all --timeout=900s

echo "==> Adding gitlab.gitlab.local to /etc/hosts"
sudo sed -i '/# iot-bonus/d' /etc/hosts
echo "127.0.0.1 gitlab.gitlab.local # iot-bonus" | sudo tee -a /etc/hosts

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
