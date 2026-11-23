#!/usr/bin/env bash
# Checks the live app is the build we just deployed and the API works.
# Usage: smoke_test.sh <port> <expected_build_number>
set -euo pipefail

PORT="${1:?Usage: smoke_test.sh <port> <build_number>}"
EXPECTED_BUILD="${2:?missing build number}"
BASE="http://${HEALTH_HOST:-localhost}:${PORT}"

LIVE_BUILD="$(curl -s --fail "${BASE}/api/version" | python3 -c 'import json,sys; print(json.load(sys.stdin)["build_number"])')"
if [[ "$LIVE_BUILD" != "$EXPECTED_BUILD" ]]; then
    echo "[smoke] FAILED: expected build ${EXPECTED_BUILD} but build ${LIVE_BUILD} is live" >&2
    exit 1
fi
echo "[smoke] Build #${LIVE_BUILD} is live"

STATUS="$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE}/api/tasks" \
    -H 'Content-Type: application/json' -d '{"title":"smoke test"}')"
if [[ "$STATUS" != "201" ]]; then
    echo "[smoke] FAILED: POST /api/tasks returned ${STATUS}" >&2
    exit 1
fi
echo "[smoke] API create-task check passed"
