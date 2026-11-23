#!/usr/bin/env bash
# Manually roll back to a specific earlier build.
# Usage: rollback.sh <image_name> <build_number> <container_name> <host_port>
# Example: bash scripts/rollback.sh task-manager-api 12 task-manager-api 8081
set -euo pipefail

IMAGE="${1:?Usage: rollback.sh <image> <build_number> <container> <port>}"
TAG="${2:?missing build number}"
CONTAINER="${3:?missing container name}"
PORT="${4:?missing port}"

if ! docker image inspect "${IMAGE}:${TAG}" > /dev/null 2>&1; then
    echo "[rollback] Image ${IMAGE}:${TAG} not found. Available tags:" >&2
    docker images "$IMAGE" --format '  {{.Tag}}  ({{.CreatedSince}})' >&2
    exit 1
fi

bash "$(dirname "$0")/deploy.sh" "$IMAGE" "$TAG" "$CONTAINER" "$PORT"
