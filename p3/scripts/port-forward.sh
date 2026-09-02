#!/bin/bash
# Opens the Argo CD UI and the application on localhost. Press Ctrl-C to stop.
set -e

kubectl -n argocd port-forward svc/argocd-server 8080:443 &
kubectl -n dev port-forward svc/wil-playground 8888:8888 &

echo
echo "Argo CD:     https://localhost:8080  (user: admin)"
echo "Application: http://localhost:8888"
echo "Press Ctrl-C to stop."

# Stop both port-forwards when this script exits
trap 'kill 0' EXIT
wait
