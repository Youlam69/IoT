#!/bin/bash
# Builds and pushes v1 and v2 for amd64 + arm64. Run docker login first.
#   ./build.sh [dockerhub-username]
set -e

HUB=${1:-eldergriffi}
cd "$(dirname "$0")"

# The default builder cannot do multi-platform
docker buildx inspect multiarch >/dev/null 2>&1 || docker buildx create --name multiarch
docker buildx use multiarch

for v in v1 v2; do
  docker buildx build --platform linux/amd64,linux/arm64 \
    --build-arg VERSION=$v -t "$HUB/playground:$v" --push .
done
