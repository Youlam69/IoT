#!/bin/bash
# Switches the deployed version between v1 and v2, then pushes so Argo CD syncs.
#   ./switch-version.sh        toggle
#   ./switch-version.sh v2     pick a version
set -e

cd "$(dirname "$0")"

CURRENT=$(grep -o 'playground:v[0-9]' deployment.yaml | cut -d: -f2)
if [ -n "$1" ]; then
  TARGET=$1
elif [ "$CURRENT" = "v1" ]; then
  TARGET=v2
else
  TARGET=v1
fi

if [ "$CURRENT" = "$TARGET" ]; then
  echo "Already on $TARGET."
  exit 0
fi

echo "==> $CURRENT -> $TARGET"
sed -i "s|playground:$CURRENT|playground:$TARGET|" deployment.yaml

git add deployment.yaml
git commit -m "deploy $TARGET"
git push

echo "==> Pushed. Watch it with: kubectl -n dev get pods -w"
