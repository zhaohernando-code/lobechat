#!/usr/bin/env bash

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${LOBE_PORT:-3210}"
DOCKER_WAIT_SECONDS="${LOBE_DOCKER_WAIT_SECONDS:-300}"
RECOVERY_COOLDOWN_SECONDS="${LOBE_RECOVERY_COOLDOWN_SECONDS:-300}"
STATE_DIR="${LOBE_WATCH_STATE_DIR:-$HOME/.cache/codex/lobechat-watch}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

mkdir -p "$STATE_DIR"

cooldown_allows() {
  local key="$1"
  local file="$STATE_DIR/${key}.last"
  local now last remaining
  now="$(date '+%s')"
  last="0"
  if [[ -f "$file" ]]; then
    last="$(tr -dc '0-9' <"$file" || true)"
    last="${last:-0}"
  fi
  if (( now - last < RECOVERY_COOLDOWN_SECONDS )); then
    remaining=$((RECOVERY_COOLDOWN_SECONDS - (now - last)))
    log "Skipping ${key} recovery; cooldown has ${remaining}s remaining."
    return 1
  fi
  printf '%s\n' "$now" >"$file"
  return 0
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

probe_release_health() {
  "$REPO_ROOT/scripts/lobehubctl.sh" health >/dev/null 2>&1
}

probe_search_health() {
  "$REPO_ROOT/scripts/lobehubctl.sh" health-search >/dev/null 2>&1
}

wait_for_docker
ensure_stack

while true; do
  if ! probe_local_url; then
    log "Local LobeHub probe failed on 127.0.0.1:${PORT}; restarting Compose stack."
    if cooldown_allows "compose-stack"; then
      wait_for_docker
      ensure_stack || true
    fi
  elif ! probe_search_health; then
    log "SearXNG JSON health failed; recreating search container."
    if cooldown_allows "searxng"; then
      wait_for_docker
      "$REPO_ROOT/scripts/lobehubctl.sh" recreate-search || true
    fi
  elif ! probe_release_health; then
    log "LobeHub release health failed; recreating app container so runtime auth/env changes take effect."
    if cooldown_allows "lobe"; then
      wait_for_docker
      "$REPO_ROOT/scripts/lobehubctl.sh" recreate-lobe || true
    fi
  fi
  sleep 30
done
