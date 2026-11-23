#!/usr/bin/env bash
# Deletes old numbered image tags, keeping the newest N (default 5).
# Usage: cleanup_images.sh <image_name> [keep]
set -euo pipefail

IMAGE="${1:?Usage: cleanup_images.sh <image> [keep]}"
KEEP="${2:-5}"

OLD_TAGS="$(docker images "$IMAGE" --format '{{.Tag}}' | grep -E '^[0-9]+$' | sort -rn | tail -n +$((KEEP + 1)) || true)"
for tag in $OLD_TAGS; do
    echo "[cleanup] Removing ${IMAGE}:${tag}"
    docker rmi "${IMAGE}:${tag}" > /dev/null 2>&1 || true
done
echo "[cleanup] Done (kept newest ${KEEP} builds)"
