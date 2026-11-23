#!/usr/bin/env bash
# Server and container monitoring with threshold alerts.
#
# Checks: container running + healthy, app /health endpoint, container CPU and
# memory, server disk usage. Problems are printed and appended to an alert log.
# Exit code 1 if any check fails, so it can be used by cron or Jenkins.
#
# Usage:  monitor.sh [container_name] [port]
# Cron (every 5 minutes):
#   */5 * * * * /path/to/scripts/monitor.sh task-manager-api 8081 >> /var/log/task-manager-monitor.log 2>&1
CONTAINER="${1:-task-manager-api}"
PORT="${2:-8081}"
CPU_LIMIT="${CPU_LIMIT:-80}"        # percent
MEM_LIMIT="${MEM_LIMIT:-80}"        # percent of the container's memory limit
DISK_LIMIT="${DISK_LIMIT:-85}"      # percent of the root disk
ALERT_LOG="${ALERT_LOG:-$HOME/task-manager-alerts.log}"

problems=0
alert() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1"
    echo "$msg"
    echo "$msg" >> "$ALERT_LOG"
    problems=$((problems + 1))
}
ok() { echo "[OK] $1"; }

echo "=== Monitoring ${CONTAINER} ($(date '+%Y-%m-%d %H:%M:%S')) ==="

# 1. Is the container running, and what does Docker's HEALTHCHECK say?
state="$(docker inspect --format '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "missing")"
health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$CONTAINER" 2>/dev/null || echo "n/a")"
if [[ "$state" == "running" ]]; then ok "Container running (health: ${health})"; else alert "Container state is '${state}'"; fi
[[ "$health" == "unhealthy" ]] && alert "Docker reports the container as unhealthy"

# 2. Does the app answer?
if curl --silent --fail --max-time 3 "http://${HEALTH_HOST:-localhost}:${PORT}/health" > /dev/null; then
    ok "/health endpoint responding"
else
    alert "/health endpoint not responding on port ${PORT}"
fi

# 3. Container CPU and memory
if [[ "$state" == "running" ]]; then
    read -r cpu mem < <(docker stats --no-stream --format '{{.CPUPerc}} {{.MemPerc}}' "$CONTAINER" | tr -d '%')
    cpu_int="${cpu%.*}"; mem_int="${mem%.*}"
    if (( cpu_int >= CPU_LIMIT )); then alert "CPU at ${cpu}% (limit ${CPU_LIMIT}%)"; else ok "CPU ${cpu}%"; fi
    if (( mem_int >= MEM_LIMIT )); then alert "Memory at ${mem}% (limit ${MEM_LIMIT}%)"; else ok "Memory ${mem}%"; fi
fi

# 4. Server disk
disk="$(df -P / | awk 'NR==2 {gsub("%", "", $5); print $5}')"
if (( disk >= DISK_LIMIT )); then alert "Disk at ${disk}% (limit ${DISK_LIMIT}%)"; else ok "Disk ${disk}%"; fi

echo "=== ${problems} problem(s) found ==="
[[ "$problems" -eq 0 ]]
