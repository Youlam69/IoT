#!/bin/bash
# Creates the k3d cluster, installs Argo CD and lets it deploy the application.
set -e

DIR=$(dirname "$0")/..

echo "==> Creating the k3d cluster"
k3d cluster list | grep -q '^iot ' || k3d cluster create --config "$DIR/confs/k3d-cluster.yaml"
kubectl config use-context k3d-iot

echo "==> Creating the argocd and dev namespaces"
kubectl apply -f "$DIR/confs/namespaces.yaml"

# --server-side: the ApplicationSet CRD is ~340 KB and a client-side apply
# stores it in an annotation, which the API server caps at 256 KB.
echo "==> Installing Argo CD"
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Argo CD checks git every 3 minutes by default; 30s makes the demo quicker
kubectl -n argocd patch configmap argocd-cm --patch-file "$DIR/confs/argocd-cm-patch.yaml"
kubectl -n argocd rollout restart deployment/argocd-repo-server \
  statefulset/argocd-application-controller

echo "==> Waiting for Argo CD"
kubectl -n argocd wait --for=condition=Available deployment --all --timeout=900s

echo "==> Telling Argo CD which application to deploy"
kubectl apply -f "$DIR/confs/application.yaml"

kubectl get ns
"$DIR/scripts/credentials.sh"
echo "Open the UI and the app with: $DIR/scripts/port-forward.sh"
