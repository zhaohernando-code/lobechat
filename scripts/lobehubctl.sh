#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/deploy/docker-compose.yml"
ENV_FILE="$ROOT_DIR/deploy/.env"
BACKUP_DIR="$ROOT_DIR/backups"

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
    compose pull
    ;;
  up)
    require_env
    compose up -d
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
  config       Validate Docker Compose config
  pull         Pull images
  up           Start services
  down         Stop services
  restart      Restart services
  ps           Show service status
  logs [svc]   Follow logs, default lobe
  backup       Dump PostgreSQL and archive data/
  restore-db   Restore PostgreSQL from a .sql dump
USAGE
    ;;
esac
