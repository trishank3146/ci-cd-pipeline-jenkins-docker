#!/usr/bin/env bash
# Waits until the app's /health endpoint responds, or fails after N tries.
# Usage: healthcheck.sh <port> [retries] [delay_seconds]
set -euo pipefail

PORT="${1:?Usage: healthcheck.sh <port> [retries] [delay]}"
RETRIES="${2:-10}"
DELAY="${3:-3}"
HOST="${HEALTH_HOST:-localhost}"   # Jenkins in Docker uses host.docker.internal
URL="http://${HOST}:${PORT}/health"

for ((i = 1; i <= RETRIES; i++)); do
    if curl --silent --fail --max-time 3 "$URL" > /dev/null; then
        echo "[health] OK: ${URL} responded (attempt ${i}/${RETRIES})"
        exit 0
    fi
    echo "[health] Waiting for ${URL} (attempt ${i}/${RETRIES})..."
    sleep "$DELAY"
done

echo "[health] FAILED: ${URL} did not become healthy" >&2
exit 1
