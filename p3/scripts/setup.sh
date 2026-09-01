#!/bin/bash
# Creates the k3d cluster, installs Argo CD and lets it deploy the application.
set -eE

DIR=$(dirname "$0")/..

# A bare `kubectl wait` that times out only ever says "timed out waiting for
# the condition", which says nothing about why. Dump the state instead.
dump_state() {
  echo
  echo "===================== setup failed: cluster state ====================="
  kubectl get nodes -o wide 2>&1 || true
  echo "--- node capacity / pressure ---"
  kubectl describe node 2>/dev/null | grep -E "^  (cpu|memory)|Taints:|MemoryPressure|DiskPressure" || true
  for ns in argocd dev; do
    echo "--- pods in $ns ---"
    kubectl -n "$ns" get pods -o wide 2>&1 || true
    echo "--- recent events in $ns ---"
    kubectl -n "$ns" get events --sort-by=.lastTimestamp 2>/dev/null | tail -15 || true
  done
  echo "--- argocd Application ---"
  kubectl -n argocd get application wil-playground 2>/dev/null \
    || echo "(none: setup aborted before creating it, so nothing syncs from git)"
  echo "======================================================================="
}
trap dump_state ERR

# Waits for a condition, printing what is still missing so a long wait is not
# a silent hang. $1 = description, $2 = timeout in seconds, rest = the check.
wait_for() {
  local what=$1 timeout=$2; shift 2
  local deadline=$((SECONDS + timeout))
  until "$@" >/dev/null 2>&1; do
    if [ $SECONDS -ge $deadline ]; then
      echo "ERROR: timed out after ${timeout}s waiting for $what" >&2
      return 1
    fi
    sleep 5
  done
}

echo "==> Creating the k3d cluster"
k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx iot || \
  k3d cluster create --config "$DIR/confs/k3d-cluster.yaml"
kubectl config use-context k3d-iot

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

# 20 minutes, not 10: this includes pulling ~500 MB of images (argocd, redis,
# dex) on a fresh cluster, which on a slow link is most of the wait.
echo "==> Waiting for Argo CD (pulls ~500 MB of images, so give it time)"
kubectl -n argocd get pods -w &
WATCH=$!
trap 'kill $WATCH 2>/dev/null || true' EXIT
kubectl -n argocd wait --for=condition=Available deployment --all --timeout=1200s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s
kill $WATCH 2>/dev/null || true

echo "==> Telling Argo CD which application to deploy"
kubectl apply -f "$DIR/confs/application.yaml"

echo "==> Waiting for Argo CD to create the application in the dev namespace"
wait_for "Argo CD to sync the deployment out of git" 300 \
  kubectl -n dev get deployment wil-playground
kubectl -n dev rollout status deployment/wil-playground --timeout=300s

kubectl get ns
"$DIR/scripts/credentials.sh"
echo "Open the UI and the app with: $DIR/scripts/port-forward.sh"
