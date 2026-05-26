# LobeChat Deployment Decisions

[2026-05-27T00:20:00+08:00] Global local Office MCP baseline decision:
`local-office-mcp` is a deployment-level capability, not a per-account optional setup step. The wrapper must continuously sync the local Office MCP custom plugin, the local Office market skill row, DeepSeek agent plugin lists, and user default-agent plugin lists to every current user so newly provisioned root-domain accounts can use Office/file tools without manual DB patching.

补充说明
- LobeHub stores custom plugins and local skills per user, so "global" means an idempotent deployment baseline sync over all users rather than a single shared database row.
- The sync keeps `local-office-mcp`, `openclaw-skills-office-mcp`, `lobe-agent-documents`, and `lobe-skill-store` attached to DeepSeek agents and default agents, while continuing to remove `lobe-cloud-sandbox`.
- The LaunchAgent watch loop owns this sync on startup and periodically afterward, because new users can appear after the app is already running.

[2026-05-26T23:05:00+08:00] Docker resource and watcher health baseline decision:
The local Docker Desktop baseline for the full `/chat` stack is raised to 8 GiB memory, 4 CPUs, and 2 GiB swap. The LaunchAgent health loop must not recreate `searxng` solely because a volatile Chinese finance query has no result; default search health proves the local SearXNG JSON API, a stable English result path, and Browserless crawl, while `LOBE_STRICT_SEARCH_HEALTH=1` remains available for manual strict acceptance.

补充说明
- The previous 4 GiB / 2 CPU Docker Desktop allocation could run the stack, but Browserless plus LobeHub plus sidecars left little headroom during health checks.
- SearXNG upstream engine behavior includes CAPTCHA, parsing changes, and proxy-dependent failures; those are search-quality signals, not always local container defects.
- Recreating containers on every volatile upstream miss creates user-visible `/chat` recovery windows, so the watcher should reserve recreation for local API/crawl failures or strict acceptance failures.
- Browserless should not inherit the Mac host's `127.0.0.1` proxy environment. In the current Docker/TUN network, Browserless `/content` succeeds with no proxy variables, while proxy variables make Chromium fail with `ERR_PROXY_CONNECTION_FAILED` or `ERR_EMPTY_RESPONSE`.

[2026-05-20T02:30:00+08:00] Local DS Pro file and skill baseline decision:
Root DS Pro/DeepSeek assistants must use local tools for Office files, uploads, OCR, and market-skill import. Internal capabilities are not allowed to depend on the broken official LobeHub Cloud Sandbox authorization flow.

补充说明
- `/chat-s3` signed uploads preserve SigV4 query strings and forward with `Host: rustfs:9000`, because rewriting signed URLs to the public host invalidates browser PUT uploads.
- `local-office-mcp` now covers `create/read docx`, `create/read pptx`, `create/read xlsx`, text/code/Markdown reading, `/chat-s3` input resolution, OCR through host Tesseract plus `chi_sim`, and local market-skill import/list/get helpers.
- Existing DeepSeek assistants remove `lobe-cloud-sandbox`, dedupe plugin arrays, and include `local-office-mcp`, `openclaw-skills-office-mcp`, `lobe-agent-documents`, `lobe-skill-store`, and `bytedance-deer-flow-find-skills`.
- Built-in `lobe-skill-store` search remains useful, but duplicate imports can return an empty tool message; DS Pro should call `local-office-mcp/import_market_skill` for an explicit local `installed_or_updated` result.
- Official LobeHub Market Cloud Sandbox authorization remains an external-only exception until valid trusted-client credentials exist for this domain.

[2026-05-19T23:33:00+08:00] Local Office MCP live dispatch decision:
DeepSeek assistants can use the local Office MCP as a custom MCP plugin, but the live LobeHub client must dispatch installed custom-plugin tool calls by `payload.source === "mcp"`, not only by `payload.type === "mcp"`. Current LobeHub can surface the tool schema while still trying the built-in executor path, which fails with `No executor found for: local-office-mcp/create_docx`.

补充说明
- `scripts/lobehubctl.sh build-image` now patches upstream `src/store/chat/slices/plugin/actions/publicApi.ts` so source-marked MCP tool calls route through `invokeMCPTypePlugin`.
- The running image was patched and committed to `lobehub-custom:latest`, then recreated and rechecked with normal release and search/crawl health.
- A real browser `/chat` run with DeepSeek called `local-office-mcp/create_docx` and produced `live-chain-fixed-20260519-2316.docx`.
- Office MCP generated files are mirrored to `codex-server:/root/codex/dev/lobechat-office-mcp-output`, and the edge serves authenticated downloads under `/chat-files/office/*`.
- The Office MCP server runs Streamable HTTP in stateless mode so LobeHub does not retain invalid MCP session ids across local server restarts.
- OCR remains partial until host Tesseract and Chinese language packs are installed or replaced by a dedicated OCR service.

[2026-05-19T22:25:00+08:00] Local skill authorization baseline decision:
This self-hosted `/chat` deployment should not present official LobeHub cloud-skill authorization as the default path unless the deployment has valid Market trusted-client credentials for this domain. The official Market OIDC service rejects `client_id=lobechat-com` with `redirect_uri=https://hernando-zhao.cn/market-auth-callback`, and dynamic registration did not yield a usable client.

补充说明
- `office-mcp` is now treated as a local installed skill: one `agent_skills` row exists for every current user, and every DeepSeek assistant/default-agent plugin list includes `openclaw-skills-office-mcp`.
- Existing DeepSeek assistants no longer include `lobe-cloud-sandbox`, because that cloud integration triggers the broken official OIDC login prompt when `MARKET_TRUSTED_CLIENT_ID` and `MARKET_TRUSTED_CLIENT_SECRET` are absent.
- The verified root assistant profile shows `Web Browsing`, `Documents`, and `office-mcp` under `集成技能`; this is the current DS Pro baseline.

[2026-05-19T21:45:00+08:00] DeepSeek document-tool baseline decision:
Existing DeepSeek assistants should have document-related tools enabled by default, because Word/PPT reading and generation require tool execution rather than only model text generation. This was initially implemented by appending `lobe-cloud-sandbox` and `lobe-agent-documents`, but the later local-skill authorization decision supersedes the sandbox part: `lobe-cloud-sandbox` is removed until official Market trusted-client credentials exist, while `lobe-agent-documents` and `openclaw-skills-office-mcp` remain enabled.

补充说明
- The authenticated `/chat` UI shows usable DeepSeek assistant skills including Web Browsing, Documents, and local market skills under agent profile `集成技能`.
- The default public skill index does not expose a clear one-click Word/PPT/OCR marketplace skill; document work is handled through built-in sandbox/document tools or a future custom MCP.
- OCR is not fully covered by this baseline. Chinese OCR should be added as a dedicated OCR MCP/sidecar if it must be reliable for all DeepSeek assistants.

[2026-05-19T10:20:00+08:00] Browserless crawl and Chinese search decision:
The local LobeHub stack must provide its own Browserless sidecar for web-page crawl and must include Chinese-capable SearXNG engines in the default search set. LobeHub's browserless crawler errors when both `BROWSERLESS_URL` and `BROWSERLESS_TOKEN` are absent, and Bing-only SearXNG results can misread Chinese finance queries such as `A股 上证指数`.

补充说明
- Compose now runs `lobehub-browserless` on loopback `127.0.0.1:13000` and passes `BROWSERLESS_URL=http://browserless:3000` plus a local token into `lobe`.
- `CRAWLER_IMPLS=browserless,naive` keeps the rendered-page crawler first while preserving the built-in fallback for simple pages.
- SearXNG now enables `baidu`, `360search`, and `google` for Chinese coverage, keeps `bing` for English/general coverage, and disables `mojeek` because it consistently returns access-denied in this network.
- Release health must prove three user-visible boundaries: English search, Chinese finance search, and Browserless `/content` crawl.

[2026-05-19T09:38:38+08:00] SearXNG outbound proxy decision:
The local SearXNG sidecar must route outbound search-engine requests through the Mac host proxy. In the current network, host curl succeeds only with the local proxy and direct outbound requests time out; SearXNG returning a syntactically valid JSON payload with zero results is not a usable web-search signal.

补充说明
- `scripts/check-release-health.sh health-search` now requires at least one result for a normal query instead of only checking that the JSON response has a `results` field.
- The SearXNG settings use Docker Desktop's `host.docker.internal:17890` HTTP proxy endpoint so the container can reach the same local proxy that the host shell uses.

[2026-05-18T21:10:00+08:00] Search-health coverage decision:
For this wrapper, web search health is a first-class release signal, not an optional sidecar behind the `/chat` homepage probe. The LaunchAgent watch and `scripts/check-release-health.sh` must treat the loopback SearXNG JSON API on `127.0.0.1:18080` as part of release health, and search-only recovery must target `searxng` directly instead of repeatedly recreating `lobe`.

补充说明
- A healthy `http://127.0.0.1:3210/` homepage does not prove that LobeHub web search is usable; the app can stay reachable while `SearXNG` has failed or drifted.
- `scripts/lobehubctl.sh` now exposes `health-search` so operators can isolate search regressions from auth/app regressions.
- Search consumers such as stock-dashboard depend on the JSON API specifically, so the health probe must hit `format=json`, not only the human HTML page.

[2026-05-05T01:28:14+08:00] Single canonical data-root decision:
LobeHub now has exactly one local persistent data root: `/Users/hernando_zhao/codex/projects/lobechat/data`. Compose mounts PostgreSQL, Redis, and RustFS through `LOBE_DATA_DIR` instead of relative `../data/*` paths, and the LaunchAgent must start the canonical project entrypoint rather than the runtime copy.

补充说明
- The DeepSeek key disappearance was caused by running the same Compose wrapper from a different checkout path. The relative PostgreSQL bind mount pointed at `~/codex/runtime/projects/lobechat/data/postgresql`, while the real three-user database and encrypted DeepSeek key vaults were still in `~/codex/projects/lobechat/data/postgresql`.
- `hz-root` was an internal LobeHub user from that unintended runtime database, not a root-domain managed account. It must not be treated as a valid parallel account source.
- Accidental calls into `~/codex/runtime/projects/lobechat/scripts/lobehubctl.sh` redirect back to the canonical project helper so stale runtime checkouts cannot silently become a second deployment root.

[2026-05-05T00:25:30+08:00] Release watch recovery decision:
The `/chat` release watch must be able to recover from Docker Desktop being stopped, not only from the LobeHub container being down. `com.codex.lobechat.frontend` stays the long-running LaunchAgent, but its `start-local-frontend.sh` entrypoint now owns three recovery steps: set a LaunchAgent-safe Docker CLI `PATH`, start Docker Desktop with `open -g -a Docker` when `docker info` is unavailable, and then run the Compose stack plus the 3210 probe loop.

补充说明
- The incident cause was not a missing LaunchAgent: `com.codex.lobechat.frontend` was still running, but it was silently stuck waiting for Docker while `127.0.0.1:3210` had no listener.
- Compose `restart: unless-stopped` only helps after Docker daemon is running. It cannot revive containers while Docker Desktop itself is stopped.
- `.codex.deploy.json` now targets the canonical checkout and verifies `http://127.0.0.1:3210/` so future release publishes cannot skip the watched local route check.

[2026-04-28T23:05:00+08:00] Root-domain managed-user decision:
The root-domain identity source for `/chat` is now a small managed internal user store rather than a single hardcoded login. `root` remains the only administrator, while normal internal users are `member` accounts created or reset only through the root-domain account-management surface.

补充说明
- LobeHub still does not own user creation or password management.
- Multi-user support for `/chat` now depends on root-domain OIDC claims derived from the managed user store, not on any LobeHub-local password database.
- `member` users are allowed into `/chat`, but `/middle` remains root-only at the edge.

[2026-04-28T21:19:15+08:00] Mounted-subpath custom-image decision:
The final `/chat` delivery path keeps the official-image wrapper model, but mounted same-domain delivery now depends on a narrow custom image patch layer in `scripts/lobehubctl.sh build-image`. The wrapper patches upstream cached `src/spa/entry.web.tsx` and `src/layout/GlobalProvider/useUserStateRedirect.ts` so both SPA basename resolution and browser-side onboarding redirects honor `NEXT_PUBLIC_BASE_PATH`.

补充说明
- `NEXT_PUBLIC_BASE_PATH=/chat` by itself was not sufficient in the upstream build used here; the browser could still authenticate successfully and then loop between `/chat/onboarding` and root-scoped redirects.
- This remains a wrapper-owned compatibility layer, not a long-lived fork of the full upstream product. The patch surface is intentionally limited to mounted-path awareness.

[2026-04-28T16:20:00+08:00] Product-readiness truth-source decision:
For `lobechat`, the dashboard task lifecycle is no longer treated as the product acceptance signal. The board task may be administratively closed or “successful” while the public `/chat` route is still unusable. Product readiness is only established by the live public route in a real browser.

补充说明
- This round already diverged: the board flow ended, but Safari still showed `https://hernando-zhao.cn/chat/onboarding` stuck on `Loading`.
- `PROJECT_STATUS.json` and Safari verification now outrank queue state when the two disagree.

[2026-04-28T16:20:00+08:00] Debug-proxy non-solution decision:
`window.__DEBUG_PROXY__` is not a supported production basename control for `/chat`. In the current upstream bundle, that flag only switches the SPA into the hard-coded `/_dangerous_local_dev_proxy` route mode used for local frontend development against the hosted backend.

补充说明
- The flag was useful because it proved client-side route interpretation is part of the remaining failure.
- It must not remain in the final production path, and future fixes should prefer an officially supported base-path/build-time mechanism or a different integration architecture.

[2026-04-27T17:30:00+08:00] Canonical deployment-wrapper handoff decision:
This repo now uses `PROJECT_STATUS.json` as the first current-state handoff source, `DECISIONS.md` as the durable deployment and scope decision log, and `PROCESS.md` as the reusable lessons log. New sessions should not infer current readiness from scattered `docs/*` files alone.

补充说明
- Active operational specs live under `docs/contracts/`.
- Historical source-reference material lives under `docs/archive/`.
- The repo remains a deployment wrapper around the official LobeHub image rather than a long-lived fork of upstream product code.

[2026-04-27T17:30:00+08:00] Entry and auth boundary decision:
The user-facing target remains `https://hernando-zhao.cn/chat`, while the repo continues to distinguish that alias from the underlying routing and local compose runtime. Account strategy remains “pre-provisioned accounts only” until a real shared identity provider exists.

[2026-04-27T19:50:00+08:00] Official Compose alignment decision:
The local Compose file should stay close to the current official LobeHub server-database sample for runtime ordering and storage compatibility, while keeping this repo's local-only port bindings and project-local `data/` paths. Official-aligned details now include RustFS health checks, bucket initialization after health, Redis prefix/TLS values, and S3 compatibility flags.

The wrapper does not rely on service-level `env_file: .env`; instead, required variables are surfaced explicitly in `environment`. This keeps provider/auth variables available to containers while allowing static validation with `deploy/.env.example` before real secrets exist.

[2026-04-27T19:50:00+08:00] Safe auth default decision:
Before shared root-domain OIDC existed, this wrapper used `AUTH_ALLOWED_EMAILS` as a temporary guardrail because upstream treats an empty allowlist as open registration in email/password mode.

[2026-04-27T22:55:00+08:00] Control-plane deploy profile decision:
The repo's `.codex.deploy.json` uses the supported `local_runtime_service` mode. For this Docker Compose wrapper, that mode syncs the canonical wrapper back to the local project path, preserves `data/`, `backups/`, and `deploy/.env`, creates expected local directories, and validates Compose only when real deploy secrets already exist. It does not introduce a separate compose-only deploy mode.

[2026-04-28T00:46:00+08:00] Upstream auth URL compatibility decision:
This wrapper must not export `NEXT_PUBLIC_AUTH_URL`. Current upstream LobeHub images treat that variable as deprecated and refuse to keep the app process running when it is present. The wrapper now relies on `APP_URL`, `INTERNAL_APP_URL`, and header-based auth URL detection instead of preserving the older explicit auth URL export.

[2026-05-02T16:11:00+08:00] SearXNG JSON format configuration decision:
SearXNG upstream defaults (pulled via `use_default_settings: true`) restrict `search.formats` to `[html]` only, which silently blocks JSON API queries with 403 Forbidden. LobeChat's `SearXNGClient` always queries with `format=json`, so the wrapper must explicitly add `json` to the allowed formats in `searxng-settings.yml`.

补充说明
- The fix is a one-line config override: `search.formats: [html, json]` in the project-level settings file.
- This is a SearXNG config surface, not a LobeHub or wrapper code change. Future SearXNG upstream changes to default formats may require re-checking this setting.
- The `use_default_settings: true` setting is still correct; the narrower `formats` restriction is an upstream security default that the wrapper must be explicit about overriding.

[2026-04-28T12:50:00+08:00] Root-domain account unification decision:
一期账号策略改为根域统一登录 + OIDC bridge。`port80-proxy.js` is the root-domain identity boundary: it keeps issuing `hz_auth_session`, exposes a minimal OIDC Provider for LobeHub, and auto-initiates LobeHub `generic-oidc` sign-in when an already-authenticated root-domain user reaches the LobeHub sign-in route. LobeHub remains the official image and is configured as an OIDC client with email/password disabled.

补充说明
- This replaces the previous Better Auth email/password allowlist baseline because acceptance requires no second LobeHub login after root-domain login.
- `AUTH_GENERIC_OIDC_SECRET` must match the root proxy `HZ_OIDC_CLIENT_SECRET`; it is a real secret and stays out of docs/examples.
- Root-domain user expansion should happen in the root login/OIDC layer first, then flow into LobeHub via claims. Do not create a parallel LobeHub-local account system for new users.
- In this OIDC-only deployment, `AUTH_ALLOWED_EMAILS` should stay empty. The root-domain user store is now the single source of truth, and keeping a second Better Auth allowlist causes member-account drift such as `EMAIL_NOT_ALLOWED` after root-domain provisioning.
