#!/usr/bin/env bash
# Deploys a new image version with automatic rollback.
#
# 1. Remember which image the running container uses (for rollback)
# 2. Stop and remove the old container
# 3. Start the new container
# 4. Wait for /health; if it fails, roll back to the previous image
#
# Usage: deploy.sh <image_name> <tag> <container_name> <host_port>
set -euo pipefail

IMAGE="${1:?Usage: deploy.sh <image> <tag> <container> <port>}"
TAG="${2:?missing tag}"
CONTAINER="${3:?missing container name}"
PORT="${4:?missing port}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_container() {
    docker run -d \
        --name "$CONTAINER" \
        --restart unless-stopped \
        -p "${PORT}:5000" \
        "$1" > /dev/null
}

PREVIOUS_IMAGE="$(docker inspect --format '{{.Config.Image}}' "$CONTAINER" 2>/dev/null || true)"
if [[ -n "$PREVIOUS_IMAGE" ]]; then
    echo "[deploy] Currently running: ${PREVIOUS_IMAGE}"
    docker rm -f "$CONTAINER" > /dev/null
else
    echo "[deploy] No running container found (first deployment)"
fi

echo "[deploy] Starting ${IMAGE}:${TAG} on port ${PORT}"
run_container "${IMAGE}:${TAG}"

if bash "${SCRIPT_DIR}/healthcheck.sh" "$PORT" "${HEALTH_RETRIES:-10}" 3; then
    echo "[deploy] SUCCESS: ${IMAGE}:${TAG} is live"
    exit 0
fi

echo "[deploy] New version is unhealthy. Container logs:" >&2
docker logs --tail 30 "$CONTAINER" >&2 || true
docker rm -f "$CONTAINER" > /dev/null || true

if [[ -n "$PREVIOUS_IMAGE" ]]; then
    echo "[deploy] Rolling back to ${PREVIOUS_IMAGE}" >&2
    run_container "$PREVIOUS_IMAGE"
    bash "${SCRIPT_DIR}/healthcheck.sh" "$PORT" "${HEALTH_RETRIES:-10}" 3 && echo "[deploy] Rollback complete" >&2
fi
exit 1
