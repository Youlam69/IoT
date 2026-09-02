#!/bin/bash
# Creates the k3d cluster, installs Argo CD and points it at the GitHub repo.
set -e

DIR=$(dirname "$0")/..
ARGOCD_MANIFEST=https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Published by k3d: 8080 -> Argo CD, 8888 -> the app
echo "==> Creating the k3d cluster"
k3d cluster list | grep -q '^iot ' || k3d cluster create iot \
  -p "8080:30080@loadbalancer" -p "8888:30888@loadbalancer" \
  --k3s-arg "--disable=metrics-server@server:*"
kubectl config use-context k3d-iot

echo "==> Creating the argocd and dev namespaces"
kubectl apply -f "$DIR/confs/namespaces.yaml"

echo "==> Installing Argo CD"
kubectl apply --server-side --force-conflicts -n argocd -f "$ARGOCD_MANIFEST"

# Unused here: SSO, notifications, ApplicationSets
kubectl -n argocd delete deployment --ignore-not-found argocd-dex-server \
  argocd-notifications-controller argocd-applicationset-controller

echo "==> Configuring Argo CD"
# Check git every 30s instead of the default 3 minutes
kubectl -n argocd patch configmap argocd-cm -p '{"data":{"timeout.reconciliation":"30s"}}'
# Serve the UI on the published NodePort
kubectl -n argocd patch svc argocd-server \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"nodePort":30080}]}}'
# They read argocd-cm at startup
kubectl -n argocd rollout restart deployment/argocd-repo-server \
  statefulset/argocd-application-controller

echo "==> Waiting for Argo CD"
kubectl -n argocd wait --for=condition=Available deployment --all --timeout=900s

echo "==> Telling Argo CD which repo to deploy"
kubectl apply -f "$DIR/confs/application.yaml"

kubectl get ns
"$DIR/scripts/credentials.sh"
echo "Argo CD:     https://localhost:8080"
echo "Application: http://localhost:8888"
