#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/deploy/docker-compose.yml"
ENV_FILE="$ROOT_DIR/deploy/.env"
BACKUP_DIR="$ROOT_DIR/backups"
CACHE_DIR="$ROOT_DIR/.cache/lobehub-upstream"

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

require_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing $ENV_FILE. Copy deploy/.env.example to deploy/.env first." >&2
    exit 1
  fi
}

load_env() {
  require_env
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

build_image() {
  load_env
  require_tool git
  require_tool docker
  local upstream_repo="${LOBEHUB_UPSTREAM_REPO:-https://github.com/lobehub/lobehub.git}"
  local upstream_ref="${2:-${LOBEHUB_UPSTREAM_REF:-main}}"
  local image_tag="${3:-${LOBEHUB_IMAGE:-lobehub-custom:latest}}"
  local base_path="${NEXT_PUBLIC_BASE_PATH:-/chat}"
  local use_cn_mirror="${USE_CN_MIRROR:-false}"
  local qstash_build_token="${QSTASH_BUILD_TOKEN:-lobehub-build-placeholder-token}"
  local docker_memory_bytes=""
  local docker_memory_mib=0
  if docker_memory_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null)" &&
    [[ "$docker_memory_bytes" =~ ^[0-9]+$ ]]; then
    docker_memory_mib=$((docker_memory_bytes / 1024 / 1024))
  fi

  local next_build_heap_mib="${LOBEHUB_BUILD_MAX_OLD_SPACE_SIZE:-}"
  if [[ -z "$next_build_heap_mib" ]]; then
    if ((docker_memory_mib > 0)); then
      next_build_heap_mib=$((docker_memory_mib * 55 / 100))
      if ((docker_memory_mib < 12288 && next_build_heap_mib > 4096)); then
        next_build_heap_mib=4096
      fi
      if ((next_build_heap_mib > 5632)); then
        next_build_heap_mib=5632
      fi
      if ((next_build_heap_mib < 3072)); then
        next_build_heap_mib=3072
      fi
    else
      next_build_heap_mib=5632
    fi
  fi

  local next_build_cpus="${LOBEHUB_BUILD_CPUS:-}"
  if [[ -z "$next_build_cpus" ]]; then
    if ((docker_memory_mib > 0 && docker_memory_mib < 12288)); then
      next_build_cpus=1
    else
      next_build_cpus=2
    fi
  fi

  local next_build_command="pnpm run build:spa && pnpm run build:spa:mobile && pnpm run build:spa:copy && NODE_OPTIONS=--max-old-space-size=${next_build_heap_mib} DOCKER=true pnpm exec next build && pnpm run build-sitemap"
  local docker_run_command="RUN bash -lc '${next_build_command}'"
  if [[ "${BUILD_NEXT_DEBUG_PRERENDER:-0}" == "1" ]]; then
    docker_run_command="RUN bash -lc '${next_build_command/next build/next build --debug-prerender}'"
  fi

  mkdir -p "$(dirname "$CACHE_DIR")"
  if [[ ! -d "$CACHE_DIR/.git" ]]; then
    git clone --filter=blob:none "$upstream_repo" "$CACHE_DIR"
  fi

  git -C "$CACHE_DIR" fetch --tags origin
  if git -C "$CACHE_DIR" rev-parse --verify --quiet "origin/$upstream_ref" >/dev/null; then
    git -C "$CACHE_DIR" checkout --force "origin/$upstream_ref"
  else
    git -C "$CACHE_DIR" checkout --force "$upstream_ref"
  fi

  local next_config_path="$CACHE_DIR/next.config.ts"
  if [[ -f "$next_config_path" ]] && ! grep -q 'LOBEHUB_BUILD_CPUS' "$next_config_path"; then
    perl -0pi -e 's/};\nconst nextConfig = defineConfig\(\{\n  \.\.\.\(isVercel \? vercelConfig : \{\}\),\n\}\);/};\nconst dockerBuildConfig =\n  process.env.DOCKER === '\''true'\''\n    ? {\n        experimental: {\n          cpus: Number(process.env.LOBEHUB_BUILD_CPUS || 1),\n        },\n      }\n    : {};\n\nconst nextConfig = defineConfig({\n  ...(isVercel ? vercelConfig : {}),\n  ...dockerBuildConfig,\n});/s' "$next_config_path"
  fi

  local spa_entry_path="$CACHE_DIR/src/spa/entry.web.tsx"
  if [[ -f "$spa_entry_path" ]] && ! grep -q 'NEXT_PUBLIC_BASE_PATH' "$spa_entry_path"; then
    python3 - "$spa_entry_path" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = """const debugProxyBase = '/_dangerous_local_dev_proxy';
const basename =
  window.__DEBUG_PROXY__ || window.location.pathname.startsWith(debugProxyBase)
    ? debugProxyBase
    : undefined;
"""
new = """const configuredBasePath = process.env.NEXT_PUBLIC_BASE_PATH;
const debugProxyBase = '/_dangerous_local_dev_proxy';
const normalizedConfiguredBasePath =
  configuredBasePath && configuredBasePath !== '/'
    ? configuredBasePath.replace(/\\/+$/, '')
    : undefined;
const basename =
  window.__DEBUG_PROXY__ || window.location.pathname.startsWith(debugProxyBase)
    ? debugProxyBase
    : normalizedConfiguredBasePath;
"""
if old not in source:
    raise SystemExit(f"Expected SPA basename block not found in {path}")
path.write_text(source.replace(old, new, 1))
PY
  fi

  local user_redirect_path="$CACHE_DIR/src/layout/GlobalProvider/useUserStateRedirect.ts"
  if [[ -f "$user_redirect_path" ]] && ! grep -q 'normalizedCurrentPath' "$user_redirect_path"; then
    python3 - "$user_redirect_path" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = """const redirectIfNotOn = (currentPath: string, path: string) => {
  if (!currentPath.startsWith(path)) {
    window.location.href = path;
  }
};
"""
new = """const configuredBasePath = process.env.NEXT_PUBLIC_BASE_PATH;
const normalizedConfiguredBasePath =
  configuredBasePath && configuredBasePath !== '/'
    ? configuredBasePath.replace(/\\/+$/, '')
    : '';

const stripBasePath = (pathname: string) =>
  normalizedConfiguredBasePath && pathname.startsWith(normalizedConfiguredBasePath)
    ? pathname.slice(normalizedConfiguredBasePath.length) || '/'
    : pathname;

const withBasePath = (pathname: string) =>
  normalizedConfiguredBasePath ? `${normalizedConfiguredBasePath}${pathname}` : pathname;

const redirectIfNotOn = (currentPath: string, path: string) => {
  const normalizedCurrentPath = stripBasePath(currentPath);
  if (!normalizedCurrentPath.startsWith(path)) {
    window.location.href = withBasePath(path);
  }
};
"""
if old not in source:
    raise SystemExit(f"Expected user redirect block not found in {path}")
path.write_text(source.replace(old, new, 1))
PY
  fi

  local dockerfile_path="$CACHE_DIR/Dockerfile.database"
  if [[ ! -f "$dockerfile_path" ]]; then
    dockerfile_path="$CACHE_DIR/Dockerfile"
  fi
  if [[ ! -f "$dockerfile_path" ]]; then
    echo "Missing Dockerfile entrypoint in $CACHE_DIR. Upstream layout changed." >&2
    exit 1
  fi

  local patched_dockerfile="$CACHE_DIR/.codex-build.Dockerfile"
  awk -v docker_run_command="$docker_run_command" '
    {
      if ($0 ~ /^RUN npm run build:docker$/) {
        print "ARG QSTASH_TOKEN"
        print "ARG BUILD_AUTH_SECRET"
        print "ARG LOBEHUB_BUILD_CPUS"
        print "ENV QSTASH_TOKEN=\"${QSTASH_TOKEN}\""
        print "ENV AUTH_SECRET=\"${BUILD_AUTH_SECRET}\""
        print "ENV BETTER_AUTH_SECRET=\"${BUILD_AUTH_SECRET}\""
        print "ENV LOBEHUB_BUILD_CPUS=\"${LOBEHUB_BUILD_CPUS}\""
        print docker_run_command
        next
      }
      print
    }
  ' "$dockerfile_path" > "$patched_dockerfile"

  docker build \
    --file "$patched_dockerfile" \
    --tag "$image_tag" \
    --build-arg "NEXT_PUBLIC_BASE_PATH=$base_path" \
    --build-arg "USE_CN_MIRROR=$use_cn_mirror" \
    --build-arg "QSTASH_TOKEN=$qstash_build_token" \
    --build-arg "BUILD_AUTH_SECRET=lobehub-build-placeholder-auth-secret-0123456789" \
    --build-arg "LOBEHUB_BUILD_CPUS=$next_build_cpus" \
    "$CACHE_DIR"

  echo "Built $image_tag from $upstream_repo @ $upstream_ref with NEXT_PUBLIC_BASE_PATH=$base_path USE_CN_MIRROR=$use_cn_mirror"
}

random_secret() {
  openssl rand -base64 32
}

case "${1:-help}" in
  secrets)
    echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)"
    echo "AUTH_SECRET=$(random_secret)"
    echo "KEY_VAULTS_SECRET=$(random_secret)"
    echo "RUSTFS_SECRET_KEY=$(openssl rand -hex 32)"
    ;;
  config)
    require_env
    compose config >/dev/null
    echo "Compose config OK"
    ;;
  pull)
    require_env
    compose pull postgresql redis rustfs rustfs-init searxng
    ;;
  build-image)
    build_image "$@"
    ;;
  up)
    require_env
    compose up -d
    ;;
  recreate-lobe)
    require_env
    compose up -d --force-recreate lobe
    ;;
  health)
    "$ROOT_DIR/scripts/check-release-health.sh"
    ;;
  down)
    require_env
    compose down
    ;;
  restart)
    require_env
    compose restart
    ;;
  ps)
    require_env
    compose ps
    ;;
  logs)
    require_env
    compose logs -f "${2:-lobe}"
    ;;
  backup)
    load_env
    mkdir -p "$BACKUP_DIR"
    stamp="$(date +%Y%m%d-%H%M%S)"
    compose exec -T postgresql pg_dump -U postgres "${LOBE_DB_NAME:-lobechat}" > "$BACKUP_DIR/lobehub-$stamp.sql"
    tar -C "$ROOT_DIR" -czf "$BACKUP_DIR/lobehub-data-$stamp.tar.gz" data
    echo "Backup written to $BACKUP_DIR with stamp $stamp"
    ;;
  restore-db)
    load_env
    dump_path="${2:-}"
    if [[ -z "$dump_path" || ! -f "$dump_path" ]]; then
      echo "Usage: $0 restore-db <backup.sql>" >&2
      exit 1
    fi
    compose exec -T postgresql psql -U postgres "${LOBE_DB_NAME:-lobechat}" < "$dump_path"
    ;;
  help|*)
    cat <<'USAGE'
Usage: scripts/lobehubctl.sh <command>

Commands:
  secrets      Print generated secrets for deploy/.env
  build-image  Build the custom LobeHub image with NEXT_PUBLIC_BASE_PATH; honors USE_CN_MIRROR=true
  config       Validate Docker Compose config
  pull         Pull infra images (does not overwrite the local custom LobeHub image)
  up           Start services
  recreate-lobe Recreate only the LobeHub app container
  health       Validate local route and root-domain OIDC sign-in bootstrap
  down         Stop services
  restart      Restart services
  ps           Show service status
  logs [svc]   Follow logs, default lobe
  backup       Dump PostgreSQL and archive data/
  restore-db   Restore PostgreSQL from a .sql dump
USAGE
    ;;
esac
