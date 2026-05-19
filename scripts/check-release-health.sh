#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/deploy/.env"
PORT="${LOBE_PORT:-3210}"
SEARXNG_PORT="${SEARXNG_PORT:-18080}"
BROWSERLESS_PORT="${BROWSERLESS_PORT:-13000}"
BROWSERLESS_TOKEN="${BROWSERLESS_TOKEN:-lobehub-local-browserless}"
EXPECTED_APP_URL="${LOBE_EXPECTED_APP_URL:-https://hernando-zhao.cn}"
EXPECTED_OIDC_ISSUER="${LOBE_EXPECTED_OIDC_ISSUER:-https://hernando-zhao.cn}"
MODE="${1:-full}"

fail() {
  echo "LobeChat release health failed: $*" >&2
  exit 1
}

check_search_health() {
  check_one_search "openai" "SearXNG English search returned no usable results"
  check_one_search "A股 上证指数" "SearXNG Chinese finance search returned no usable results" "上证|东方财富|新浪|A股|指数|同花顺"
}

check_one_search() {
  local query="$1"
  local error_message="$2"
  local expected_pattern="${3:-}"
  local search_response
  search_response="$(
    curl -fsS \
      --get "http://127.0.0.1:${SEARXNG_PORT}/search" \
      --data-urlencode "q=${query}" \
      --data "format=json"
  )" || fail "SearXNG JSON API is not reachable on 127.0.0.1:${SEARXNG_PORT}"

  SEARCH_RESPONSE="$search_response" EXPECTED_PATTERN="$expected_pattern" python3 - <<'PY' || fail "$error_message"
import json
import os
import re
import sys

try:
    payload = json.loads(os.environ.get("SEARCH_RESPONSE", ""))
except json.JSONDecodeError:
    sys.exit(1)

results = payload.get("results")
if not isinstance(results, list) or len(results) == 0:
    sys.exit(1)

pattern = os.environ.get("EXPECTED_PATTERN", "")
if pattern:
    joined = "\n".join(
        f"{item.get('title', '')}\n{item.get('content', '')}\n{item.get('url', '')}"
        for item in results[:10]
        if isinstance(item, dict)
    )
    if not re.search(pattern, joined, re.I):
        sys.exit(1)
PY
}

check_browserless_health() {
  local content_response
  content_response="$(
    curl -fsS \
      --max-time 30 \
      -H 'content-type: application/json' \
      --data '{"url":"https://example.com","gotoOptions":{"waitUntil":"networkidle0"}}' \
      "http://127.0.0.1:${BROWSERLESS_PORT}/content?token=${BROWSERLESS_TOKEN}"
  )" || fail "Browserless /content API is not reachable on 127.0.0.1:${BROWSERLESS_PORT}"

  if [[ "$content_response" != *"Example Domain"* ]]; then
    fail "Browserless /content API did not return rendered page content"
  fi
}

require_env_value() {
  local name="$1"
  local expected="${2:-}"
  local value="${!name:-}"

  if [[ -z "$value" ]]; then
    fail "$name is empty in deploy/.env"
  fi

  if [[ -n "$expected" && "$value" != "$expected" ]]; then
    fail "$name is '$value', expected '$expected'"
  fi
}

case "$MODE" in
  full|search)
    ;;
  *)
    fail "unsupported mode '$MODE'; expected 'full' or 'search'"
    ;;
esac

if [[ ! -f "$ENV_FILE" ]]; then
  fail "missing $ENV_FILE"
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

PORT="${LOBE_PORT:-$PORT}"
SEARXNG_PORT="${SEARXNG_PORT:-$SEARXNG_PORT}"
BROWSERLESS_PORT="${BROWSERLESS_PORT:-$BROWSERLESS_PORT}"
BROWSERLESS_TOKEN="${BROWSERLESS_TOKEN:-$BROWSERLESS_TOKEN}"

if [[ "$MODE" == "search" ]]; then
  check_search_health
  check_browserless_health
  echo "LobeChat search and crawl health OK"
  exit 0
fi

require_env_value APP_URL "$EXPECTED_APP_URL"
require_env_value AUTH_DISABLE_EMAIL_PASSWORD "1"
require_env_value AUTH_SSO_PROVIDERS "generic-oidc"
require_env_value AUTH_GENERIC_OIDC_ID "lobehub"
require_env_value AUTH_GENERIC_OIDC_SECRET
require_env_value AUTH_GENERIC_OIDC_ISSUER "$EXPECTED_OIDC_ISSUER"
require_env_value SEARCH_PROVIDERS "searxng"
require_env_value CRAWLER_IMPLS
require_env_value BROWSERLESS_URL
require_env_value BROWSERLESS_TOKEN

if ! curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null; then
  fail "local LobeHub route is not reachable on 127.0.0.1:${PORT}"
fi

auth_response="$(
  curl -fsS \
    -H 'content-type: application/json' \
    -H 'accept: application/json' \
    --data '{"providerId":"generic-oidc","callbackURL":"https://hernando-zhao.cn/chat/"}' \
    "http://127.0.0.1:${PORT}/api/auth/sign-in/oauth2"
)"

if [[ "$auth_response" != *'"redirect":true'* || "$auth_response" != *'/oidc/authorize'* ]]; then
  fail "Better Auth generic-oidc sign-in endpoint did not return an OIDC redirect"
fi

check_search_health
check_browserless_health

echo "LobeChat release health OK"
