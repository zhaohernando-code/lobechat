# LobeChat Deployment Decisions

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

[2026-04-28T12:50:00+08:00] Root-domain account unification decision:
一期账号策略改为根域统一登录 + OIDC bridge。`port80-proxy.js` is the root-domain identity boundary: it keeps issuing `hz_auth_session`, exposes a minimal OIDC Provider for LobeHub, and auto-initiates LobeHub `generic-oidc` sign-in when an already-authenticated root-domain user reaches the LobeHub sign-in route. LobeHub remains the official image and is configured as an OIDC client with email/password disabled.

补充说明
- This replaces the previous Better Auth email/password allowlist baseline because acceptance requires no second LobeHub login after root-domain login.
- `AUTH_GENERIC_OIDC_SECRET` must match the root proxy `HZ_OIDC_CLIENT_SECRET`; it is a real secret and stays out of docs/examples.
- Root-domain user expansion should happen in the root login/OIDC layer first, then flow into LobeHub via claims. Do not create a parallel LobeHub-local account system for new users.
- In this OIDC-only deployment, `AUTH_ALLOWED_EMAILS` should stay empty. The root-domain user store is now the single source of truth, and keeping a second Better Auth allowlist causes member-account drift such as `EMAIL_NOT_ALLOWED` after root-domain provisioning.
