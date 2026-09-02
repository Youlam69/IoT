#!/bin/bash
# Builds both versions for amd64 + arm64 and pushes them to Docker Hub.
#   docker login
#   ./build.sh [dockerhub-username]
set -e

HUB=${1:-eldergriffi}
cd "$(dirname "$0")"

# The default builder cannot do multi-platform; this one can.
docker buildx inspect multiarch >/dev/null 2>&1 || docker buildx create --name multiarch
docker buildx use multiarch

for v in v1 v2; do
  docker buildx build --platform linux/amd64,linux/arm64 \
    --build-arg VERSION=$v -t "$HUB/playground:$v" --push .
done
