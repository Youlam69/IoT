#!/bin/bash
# Prints the GitLab and Argo CD passwords.
echo
echo "GitLab:  http://gitlab.gitlab.local - user: root"
echo "Password: $(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
  -o jsonpath='{.data.password}' | base64 -d)"
echo
echo "Argo CD: https://localhost:8080 - user: admin"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)"
echo
