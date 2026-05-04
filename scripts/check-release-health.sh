#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/deploy/.env"
PORT="${LOBE_PORT:-3210}"
EXPECTED_APP_URL="${LOBE_EXPECTED_APP_URL:-https://hernando-zhao.cn}"
EXPECTED_OIDC_ISSUER="${LOBE_EXPECTED_OIDC_ISSUER:-https://hernando-zhao.cn}"

fail() {
  echo "LobeChat release health failed: $*" >&2
  exit 1
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

if [[ ! -f "$ENV_FILE" ]]; then
  fail "missing $ENV_FILE"
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

require_env_value APP_URL "$EXPECTED_APP_URL"
require_env_value AUTH_DISABLE_EMAIL_PASSWORD "1"
require_env_value AUTH_SSO_PROVIDERS "generic-oidc"
require_env_value AUTH_GENERIC_OIDC_ID "lobehub"
require_env_value AUTH_GENERIC_OIDC_SECRET
require_env_value AUTH_GENERIC_OIDC_ISSUER "$EXPECTED_OIDC_ISSUER"

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

echo "LobeChat release health OK"
