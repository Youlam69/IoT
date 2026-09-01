#!/bin/bash
# Creates the k3d cluster, installs Argo CD and lets it deploy the application.
set -e

DIR=$(dirname "$0")/..

echo "==> Creating the k3d cluster"
k3d cluster list iot >/dev/null 2>&1 || k3d cluster create --config "$DIR/confs/k3d-cluster.yaml"

# Get kubeconfig properly for the current user without touching /etc/rancher directly via k3d merge bug
mkdir -p ~/.kube
k3d kubeconfig write iot --output ~/.kube/config-iot
export KUBECONFIG=~/.kube/config-iot

echo "==> Creating the argocd and dev namespaces"
kubectl apply -f "$DIR/confs/namespaces.yaml"

echo "==> Installing Argo CD"
# --server-side is required: the ApplicationSet CRD is ~340 KB, and a plain
# client-side apply stores it in the last-applied-configuration annotation,
# which the API server caps at 256 KB.
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Argo CD checks git every 3 minutes by default; 30s makes the demo quicker
kubectl -n argocd patch configmap argocd-cm --patch-file "$DIR/confs/argocd-cm-patch.yaml"
kubectl -n argocd rollout restart deployment/argocd-repo-server \
  statefulset/argocd-application-controller

echo "==> Waiting for Argo CD (takes a few minutes)"
kubectl -n argocd wait --for=condition=Available deployment --all --timeout=600s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s

echo "==> Telling Argo CD which application to deploy"
kubectl apply -f "$DIR/confs/application.yaml"

echo "==> Waiting for the application to appear in the dev namespace"
for _ in $(seq 60); do
  kubectl -n dev get deployment wil-playground >/dev/null 2>&1 && break
  sleep 5
done
kubectl -n dev rollout status deployment/wil-playground --timeout=300s

kubectl get ns
"$DIR/scripts/credentials.sh"
echo "Open the UI and the app with: $DIR/scripts/port-forward.sh"
