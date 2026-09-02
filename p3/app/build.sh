#!/bin/bash
# Builds both versions for amd64 + arm64 and pushes them to Docker Hub.
#   docker login
#   ./build.sh <dockerhub-username>
set -e

HUB=${1:?usage: ./build.sh <dockerhub-username>}
cd "$(dirname "$0")"

# The default builder cannot do multi-platform; this one can.
docker buildx inspect iot >/dev/null 2>&1 || docker buildx create --name iot
docker buildx use iot

for v in v1 v2; do
  docker buildx build --platform linux/amd64,linux/arm64 \
    --build-arg VERSION=$v -t "$HUB/playground:$v" --push .
done
