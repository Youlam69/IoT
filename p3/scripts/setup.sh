#!/bin/bash
# Part 3: creates the k3d cluster, installs Argo CD, and points Argo CD at the
# GitHub repo it should deploy from. Run scripts/install.sh first.
set -e

DIR=$(dirname "$0")/..
ARGOCD_MANIFEST=https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# k3d's load balancer publishes two host ports onto NodePorts in the cluster:
#   localhost:8080 -> 30080 -> argocd-server      (the UI)
#   localhost:8888 -> 30888 -> aelyakou-playground (the application)
# That is why no port-forward is needed anywhere in this part.
echo "==> Creating the k3d cluster"
k3d cluster list | grep -q '^iot ' || k3d cluster create iot \
  -p "8080:30080@loadbalancer" -p "8888:30888@loadbalancer" \
  --k3s-arg "--disable=metrics-server@server:*"
kubectl config use-context k3d-iot

echo "==> Creating the argocd and dev namespaces"
kubectl apply -f "$DIR/confs/namespaces.yaml"

# --server-side is required, not a preference: the ApplicationSet CRD in this
# manifest is ~340 KB, and a client-side apply would store a copy of it in an
# annotation, which the API server caps at 256 KB.
echo "==> Installing Argo CD"
kubectl apply --server-side --force-conflicts -n argocd -f "$ARGOCD_MANIFEST"

echo "==> Configuring Argo CD"
# Check git every 30s instead of the default 3 minutes, so the v1 -> v2 demo
# does not keep everyone waiting
kubectl -n argocd patch configmap argocd-cm -p '{"data":{"timeout.reconciliation":"30s"}}'
# Serve the UI on the NodePort k3d publishes as https://localhost:8080
kubectl -n argocd patch svc argocd-server \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"nodePort":30080}]}}'
# These two read argocd-cm at startup, so they need a restart to see the change
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
