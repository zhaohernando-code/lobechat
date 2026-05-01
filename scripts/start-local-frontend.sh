#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${LOBE_PORT:-3210}"

wait_for_docker() {
  until docker info >/dev/null 2>&1; do
    sleep 5
  done
}

ensure_stack() {
  "$REPO_ROOT/scripts/lobehubctl.sh" up
}

probe_local_url() {
  curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null 2>&1
}

wait_for_docker
ensure_stack

while true; do
  if ! probe_local_url; then
    ensure_stack || true
  fi
  sleep 30
done
