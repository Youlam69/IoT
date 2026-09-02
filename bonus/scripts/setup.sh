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

# The chart stopped bundling these in 10.0.0, so GitLab needs them up first
echo "==> Installing PostgreSQL and Redis"
kubectl apply -f "$DIR/bonus/confs/database.yaml"
kubectl -n gitlab rollout status deployment/gitlab-postgresql --timeout=300s
kubectl -n gitlab rollout status deployment/gitlab-redis --timeout=300s

# Pinned to the version we tested; 10.3.1 is GitLab 19.3.1, the current release
echo "==> Installing GitLab with Helm (go get a coffee)"
helm repo add gitlab https://charts.gitlab.io/
helm upgrade --install gitlab gitlab/gitlab --version 10.3.1 --namespace gitlab \
  --values "$DIR/bonus/confs/gitlab-values.yaml" --timeout 30m --wait

echo "==> Installing Argo CD"
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Not used here: SSO, notifications and ApplicationSets
kubectl -n argocd delete deployment --ignore-not-found argocd-dex-server \
  argocd-notifications-controller argocd-applicationset-controller
kubectl -n argocd patch configmap argocd-cm -p '{"data":{"timeout.reconciliation":"30s"}}'
kubectl -n argocd patch svc argocd-server \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"nodePort":30080}]}}'
kubectl -n argocd rollout restart deployment/argocd-repo-server \
  statefulset/argocd-application-controller
kubectl -n argocd wait --for=condition=Available deployment --all --timeout=900s

echo "==> Adding gitlab.gitlab.local to /etc/hosts"
sudo sed -i '/# iot-bonus/d' /etc/hosts
echo "127.0.0.1 gitlab.gitlab.local # iot-bonus" | sudo tee -a /etc/hosts

GITLAB=http://gitlab.gitlab.local
PROJECT=aelyakou-iot

echo "==> Waiting for the GitLab web interface"
for _ in $(seq 90); do
  curl -sfo /dev/null "$GITLAB/users/sign_in" && break
  sleep 10
done

ROOT_PW=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
  -o jsonpath='{.data.password}' | base64 -d)

# An API token for root, from the root password
TOKEN=$(curl -sf -X POST "$GITLAB/oauth/token" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "username=root" \
  --data-urlencode "password=$ROOT_PW" \
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
if [ -z "$TOKEN" ]; then
  echo "ERROR: could not get a GitLab API token. Do it by hand instead:" >&2
  echo "  log into $GITLAB as root, create a PUBLIC project named $PROJECT," >&2
  echo "  push $DIR/p3/app-repo/*.yaml to it, then apply bonus/confs/application.yaml" >&2
  exit 1
fi

# Public, so Argo CD needs no credentials. Already-exists is fine.
echo "==> Creating the public project $PROJECT"
curl -sf -o /dev/null -X POST "$GITLAB/api/v4/projects" \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "name=$PROJECT" \
  --data-urlencode "visibility=public" || true

# Pushed from a scratch copy so p3/app-repo's own git state is left alone
echo "==> Pushing the Part 3 manifests"
TMP=$(mktemp -d)
cp "$DIR/p3/app-repo/deployment.yaml" "$DIR/p3/app-repo/service.yaml" "$TMP/"
git -C "$TMP" init -q -b main
git -C "$TMP" add .
git -C "$TMP" -c user.email=iot@localhost -c user.name=iot commit -qm "playground v1"
git -C "$TMP" push -qf "http://oauth2:$TOKEN@gitlab.gitlab.local/root/$PROJECT.git" main
rm -rf "$TMP"

echo "==> Telling Argo CD to deploy it"
kubectl apply -f "$DIR/bonus/confs/application.yaml"

"$DIR/bonus/scripts/credentials.sh"
cat <<MSG
GitLab:      $GITLAB/root/$PROJECT
Argo CD:     https://localhost:8080
Application: http://localhost:8888

For the v1 -> v2 demo:
  git clone $GITLAB/root/$PROJECT.git && cd $PROJECT
  sed -i 's|playground:v1|playground:v2|' deployment.yaml
  git commit -am v2 && git push
MSG
