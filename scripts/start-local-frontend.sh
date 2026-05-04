#!/usr/bin/env bash

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${LOBE_PORT:-3210}"
DOCKER_WAIT_SECONDS="${LOBE_DOCKER_WAIT_SECONDS:-300}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

docker_ready() {
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

start_docker_desktop() {
  if docker_ready; then
    return 0
  fi

  if [[ -d /Applications/Docker.app ]]; then
    log "Docker daemon is unavailable; starting Docker Desktop."
    open -g -a Docker || true
  else
    log "Docker daemon is unavailable and /Applications/Docker.app is missing."
  fi
}

wait_for_docker() {
  local waited=0
  start_docker_desktop
  until docker_ready; do
    if (( waited >= DOCKER_WAIT_SECONDS )); then
      log "Docker daemon is still unavailable after ${DOCKER_WAIT_SECONDS}s; retrying startup."
      start_docker_desktop
      waited=0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  log "Docker daemon is available."
}

ensure_stack() {
  log "Ensuring LobeHub Compose stack is running."
  "$REPO_ROOT/scripts/lobehubctl.sh" up
}

probe_local_url() {
  curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null 2>&1
}

wait_for_docker
ensure_stack

while true; do
  if ! probe_local_url; then
    log "Local LobeHub probe failed on 127.0.0.1:${PORT}; restarting Compose stack."
    wait_for_docker
    ensure_stack || true
  fi
  sleep 30
done
