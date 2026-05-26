#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POSTGRES_CONTAINER="${LOCAL_OFFICE_MCP_POSTGRES_CONTAINER:-lobehub-postgresql}"
POSTGRES_DB="${LOCAL_OFFICE_MCP_POSTGRES_DB:-lobechat}"
POSTGRES_USER="${LOCAL_OFFICE_MCP_POSTGRES_USER:-postgres}"
DOCKER_BIN="${LOCAL_OFFICE_MCP_DOCKER_BIN:-$(command -v docker || echo /usr/local/bin/docker)}"
CANONICAL_EMAIL="${LOCAL_OFFICE_MCP_DEFAULT_USER_EMAIL:-root@hernando-zhao.cn}"
MODE="${1:-sync}"

psql_cmd() {
  "$DOCKER_BIN" exec -i "$POSTGRES_CONTAINER" psql \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    -v ON_ERROR_STOP=1 \
    -v canonical_email="$CANONICAL_EMAIL" \
    -q \
    -t \
    -A \
    -F $'\t'
}

fail() {
  echo "LobeChat Office MCP baseline failed: $*" >&2
  exit 1
}

case "$MODE" in
  sync|health)
    ;;
  *)
    fail "unsupported mode '$MODE'; expected 'sync' or 'health'"
    ;;
esac

read -r custom_plugin_count office_skill_count < <(
  psql_cmd <<'SQL'
SELECT
  (SELECT count(*) FROM user_installed_plugins WHERE identifier = 'local-office-mcp')::text,
  (SELECT count(*) FROM agent_skills WHERE identifier = 'openclaw-skills-office-mcp')::text;
SQL
)

if [[ "${custom_plugin_count:-0}" == "0" ]]; then
  fail "no canonical user_installed_plugins row for local-office-mcp"
fi

if [[ "${office_skill_count:-0}" == "0" ]]; then
  fail "no canonical agent_skills row for openclaw-skills-office-mcp"
fi

if [[ "$MODE" == "sync" ]]; then
  psql_cmd <<'SQL'
BEGIN;

INSERT INTO user_settings (id)
SELECT id
FROM users
ON CONFLICT (id) DO NOTHING;

WITH canonical_plugin AS (
  SELECT identifier, type, manifest, settings, custom_params, source
  FROM user_installed_plugins
  WHERE identifier = 'local-office-mcp'
  ORDER BY
    (user_id = (SELECT id FROM users WHERE email = :'canonical_email')) DESC,
    updated_at DESC
  LIMIT 1
)
INSERT INTO user_installed_plugins (
  user_id, identifier, type, manifest, settings, custom_params, source, created_at, updated_at, accessed_at
)
SELECT
  users.id,
  canonical_plugin.identifier,
  canonical_plugin.type,
  canonical_plugin.manifest,
  COALESCE(canonical_plugin.settings, '{}'::jsonb),
  canonical_plugin.custom_params,
  canonical_plugin.source,
  now(),
  now(),
  now()
FROM users
CROSS JOIN canonical_plugin
WHERE canonical_plugin.identifier = 'local-office-mcp'
ON CONFLICT (user_id, identifier)
DO UPDATE SET
  type = EXCLUDED.type,
  manifest = EXCLUDED.manifest,
  settings = EXCLUDED.settings,
  custom_params = EXCLUDED.custom_params,
  source = EXCLUDED.source,
  updated_at = now();

WITH canonical_skill AS (
  SELECT name, description, identifier, source, manifest, content, editor_data, resources, zip_file_hash
  FROM agent_skills
  WHERE identifier = 'openclaw-skills-office-mcp'
  ORDER BY
    (user_id = (SELECT id FROM users WHERE email = :'canonical_email')) DESC,
    updated_at DESC
  LIMIT 1
)
INSERT INTO agent_skills (
  id, name, description, identifier, source, manifest, content, editor_data, resources, zip_file_hash,
  user_id, accessed_at, created_at, updated_at
)
SELECT
  'skl_baseline_' || substr(md5(users.id || ':' || canonical_skill.identifier), 1, 16),
  canonical_skill.name,
  canonical_skill.description,
  canonical_skill.identifier,
  canonical_skill.source,
  canonical_skill.manifest,
  canonical_skill.content,
  canonical_skill.editor_data,
  canonical_skill.resources,
  canonical_skill.zip_file_hash,
  users.id,
  now(),
  now(),
  now()
FROM users
CROSS JOIN canonical_skill
ON CONFLICT (user_id, name)
DO UPDATE SET
  description = EXCLUDED.description,
  identifier = EXCLUDED.identifier,
  source = EXCLUDED.source,
  manifest = EXCLUDED.manifest,
  content = EXCLUDED.content,
  editor_data = EXCLUDED.editor_data,
  resources = EXCLUDED.resources,
  zip_file_hash = EXCLUDED.zip_file_hash,
  accessed_at = now(),
  updated_at = now();

WITH required_plugins(ord, value) AS (
  VALUES
    (1, 'lobe-agent-documents'),
    (2, 'lobe-skill-store'),
    (3, 'local-office-mcp'),
    (4, 'openclaw-skills-office-mcp')
),
normalized AS (
  SELECT
    agents.id,
    (
      SELECT jsonb_agg(value ORDER BY min_ord)
      FROM (
        SELECT value, min(ord) AS min_ord
        FROM (
          SELECT value, ord
          FROM required_plugins
          UNION ALL
          SELECT value, 100 + ord::int
          FROM jsonb_array_elements_text(COALESCE(agents.plugins, '[]'::jsonb)) WITH ORDINALITY AS existing(value, ord)
        ) AS candidates
        WHERE value <> 'lobe-cloud-sandbox'
        GROUP BY value
      ) AS deduped
    ) AS plugins
  FROM agents
  WHERE provider = 'deepseek'
)
UPDATE agents
SET plugins = normalized.plugins,
    updated_at = now()
FROM normalized
WHERE agents.id = normalized.id;

WITH required_plugins(ord, value) AS (
  VALUES
    (1, 'lobe-agent-documents'),
    (2, 'lobe-skill-store'),
    (3, 'local-office-mcp'),
    (4, 'openclaw-skills-office-mcp')
),
normalized AS (
  SELECT
    user_settings.id,
    jsonb_set(
      COALESCE(user_settings.default_agent, '{}'::jsonb),
      '{plugins}',
      (
        SELECT jsonb_agg(value ORDER BY min_ord)
        FROM (
          SELECT value, min(ord) AS min_ord
          FROM (
            SELECT value, ord
            FROM required_plugins
            UNION ALL
            SELECT value, 100 + ord::int
            FROM jsonb_array_elements_text(COALESCE(user_settings.default_agent->'plugins', '[]'::jsonb)) WITH ORDINALITY AS existing(value, ord)
          ) AS candidates
          WHERE value <> 'lobe-cloud-sandbox'
          GROUP BY value
        ) AS deduped
      ),
      true
    ) AS default_agent
  FROM user_settings
)
UPDATE user_settings
SET default_agent = normalized.default_agent
FROM normalized
WHERE user_settings.id = normalized.id;

COMMIT;
SQL
fi

summary="$(
  psql_cmd <<'SQL'
WITH required_plugins(value) AS (
  VALUES
    ('lobe-agent-documents'),
    ('lobe-skill-store'),
    ('local-office-mcp'),
    ('openclaw-skills-office-mcp')
),
checks AS (
  SELECT
    (SELECT count(*)
     FROM users u
     WHERE NOT EXISTS (
       SELECT 1 FROM user_installed_plugins p
       WHERE p.user_id = u.id AND p.identifier = 'local-office-mcp'
     )) AS users_missing_custom_plugin,
    (SELECT count(*)
     FROM users u
     WHERE NOT EXISTS (
       SELECT 1 FROM agent_skills s
       WHERE s.user_id = u.id AND s.identifier = 'openclaw-skills-office-mcp'
     )) AS users_missing_office_skill,
    (SELECT count(*)
     FROM agents a
     WHERE a.provider = 'deepseek'
       AND EXISTS (
         SELECT 1
         FROM required_plugins r
         WHERE NOT (COALESCE(a.plugins, '[]'::jsonb) ? r.value)
       )) AS deepseek_agents_missing_plugins,
    (SELECT count(*)
     FROM user_settings us
     WHERE EXISTS (
       SELECT 1
       FROM required_plugins r
       WHERE NOT (COALESCE(us.default_agent->'plugins', '[]'::jsonb) ? r.value)
     )) AS user_settings_missing_default_plugins
)
SELECT
  users_missing_custom_plugin || E'\t' ||
  users_missing_office_skill || E'\t' ||
  deepseek_agents_missing_plugins || E'\t' ||
  user_settings_missing_default_plugins
FROM checks;
SQL
)"

IFS=$'\t' read -r missing_custom missing_skill missing_agents missing_defaults <<<"$summary"

echo "Office MCP baseline: missing_custom_plugin=${missing_custom:-unknown} missing_office_skill=${missing_skill:-unknown} missing_deepseek_agent_plugins=${missing_agents:-unknown} missing_default_agent_plugins=${missing_defaults:-unknown}"

if [[ "${missing_custom:-1}" != "0" ||
  "${missing_skill:-1}" != "0" ||
  "${missing_agents:-1}" != "0" ||
  "${missing_defaults:-1}" != "0" ]]; then
  exit 1
fi
