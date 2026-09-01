#!/bin/bash
# Prints the Argo CD admin password.
echo
echo "Argo CD: https://localhost:8080 - user: admin"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)"
echo
