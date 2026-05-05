# PROCESS

## 2026-05-05

- Problem: stock-dashboard shortpick experiments need a clean, automatable search substrate for DeepSeek because the official DeepSeek API does not expose web search.
- Resolution: LobeChat's SearXNG service is acceptable for this role only as a local search backend, not as a reused browser chat session or agent state. The wrapper exposes SearXNG JSON on `127.0.0.1:18080` so callers can execute model-planned searches without inheriting LobeChat user memory, workspace files, or conversation context.
- Prevention: if another project consumes LobeChat search, keep the boundary at SearXNG/search-result data. Do not call the `/chat` browser conversation as a hidden executor unless a separate decision creates a stateless service user and proves no memory, agent prompt, or chat history is leaking.

- Problem: after restarting the release stack, the app showed only a `hz-root` LobeHub user and the three manually configured DeepSeek API keys looked missing.
- Resolution: the keys were still present in the canonical PostgreSQL data directory, but the runtime checkout had started Compose from a different relative bind mount and created/used `~/codex/runtime/projects/lobechat/data/postgresql`. The runtime data directory was backed up, canonical `data/` was restored to the served path, and the wrapper now uses explicit `LOBE_DATA_DIR=/Users/hernando_zhao/codex/projects/lobechat/data` for PostgreSQL, Redis, and RustFS.
- Prevention: never let the active LobeHub stack depend on checkout-relative `../data` paths. The LaunchAgent and deploy profile must point at the canonical project entrypoint, and accidental runtime helper calls must redirect to canonical before running Compose.

- Problem: `https://hernando-zhao.cn/chat/` returned `connect ECONNREFUSED 127.0.0.1:3210` even though `com.codex.lobechat.frontend` was loaded and running.
- Resolution: Docker Desktop was stopped, so no Compose container could bind 3210. Starting Docker Desktop let Docker's restart policies and the frontend LaunchAgent bring `lobehub-app` back. The watch script now sets a LaunchAgent-safe `PATH`, actively starts Docker Desktop when `docker info` fails, and re-enters the Compose/probe loop after local probe failures.
- Prevention: for Docker-backed release routes, a watch that only waits for Docker is incomplete. It must own Docker Desktop startup, emit enough logs to show which layer is unavailable, and the deploy profile must include the real LaunchAgent plus the public route's local health check port.

## 2026-05-02

- Problem: LobeChat 界面报告网络搜索不可用。日志显示 SearXNG search API 持续返回 403 Forbidden，而 HTML 格式搜索正常。
- Resolution: SearXNG 的 `use_default_settings: true` 拉取的上游默认配置将 `search.formats` 限制为 `[html]`，导致所有 `format=json` 请求返回 403。在 `searxng-settings.yml` 的 `search` 段显式添加 `formats: [html, json]` 覆盖默认值后恢复。
- Prevention: 使用 SearXNG 且消费者依赖 JSON API 时，必须在项目级 settings.yml 中显式声明 `search.formats` 包含 `json`，不能依赖上游默认配置。

## 2026-04-28

- Problem: the original root-domain auth bridge described `/chat` as a shared-account entry, but the real domain still only had a single hardcoded root login, so “future multi-user support” existed only on paper and not as a live identity source.
- Resolution: the root-domain edge now owns a small managed user store (`root` + `member` roles), exposes root-only account management, allows self-service password changes, and emits real per-user OIDC claims to LobeHub without enabling any LobeHub-local password login.
- Prevention: when this wrapper says “same-domain account system,” verify the root-domain identity layer itself already supports the intended user model. Do not describe downstream OIDC consumers as multi-user-ready while the upstream login source is still single-account.

- Problem: the first real `member` account (`amoeba`) could authenticate through root-domain OIDC, but Chrome still stalled on the LobeHub logo or a blank `/chat/signin` shell while `root` worked. The account was valid; the mounted app still depended on root-scoped runtime assets and APIs that the edge had only been permitting for root.
- Resolution: the edge now treats proven LobeChat runtime resources as part of the `/chat` surface for members too. Root-scoped static assets `/_spa/*`, `/_next/*`, and `/manifest.webmanifest` are allowed for authenticated members, while root-escaped runtime APIs `/api/auth/*`, `/api/user`, and `/api/config` are explicitly proxied back into the `/chat` tunnel instead of the control-plane root `/api/*`. After publishing that fix live, the real Chrome `amoeba` session reached the usable `https://hernando-zhao.cn/chat` homepage.
- Prevention: for mounted apps behind shared identity, “login succeeds” is not enough. Acceptance for non-root users must include a live browser check that every post-login root-escaped asset and runtime API still resolves to the app, not to the host site's default authorization bucket.

- Problem: creating a new root-domain `member` account still did not automatically make that user acceptable to LobeHub. The root-domain account store and LobeHub Better Auth allowlist were drifting independently, so a fresh member could pass root-domain login and still hit `EMAIL_NOT_ALLOWED` on `/chat`.
- Resolution: first verified the failure by reproducing `EMAIL_NOT_ALLOWED` for `zhangzhou`, then removed `AUTH_ALLOWED_EMAILS` from the active OIDC-only deployment instead of continuing to mirror member emails into a second list. After recreating `lobehub-app`, `zhangzhou@hernando-zhao.cn` completed the OIDC callback, received a Better Auth app session, and appeared in the LobeHub `users` table without any per-user allowlist maintenance.
- Prevention: once `/chat` is fully OIDC-only and email/password login is disabled, do not keep a second Better Auth email allowlist in the wrapper. The root-domain user store must stay the only source of truth for who can enter `/chat`.

- Problem: even after the shared-account flow worked, `/chat` still had a rough UX edge: the browser could briefly render the upstream sign-in page before the client-side auto-SSO script fired, which looked like garbled or flickering intermediate content instead of a clean same-domain handoff.
- Resolution: the root-domain edge now starts the LobeChat `generic-oidc` bridge server-side on `GET /chat/signin`, relays the upstream Better Auth state cookie, and responds with a direct `302` to `/oidc/authorize`. The older injected auto-SSO snippet remains only as a fallback path.
- Prevention: when the intended behavior is “shared account flow with no visible intermediate login page,” do not rely on browser-rendered HTML plus injected JavaScript as the primary path if the edge can deterministically start the redirect itself.

- Problem: after root-domain OIDC and `/chat` aliasing were repaired, Safari could still authenticate and land on `/chat/onboarding` while the UI stayed on `Loading`, which made it look like an edge/proxy failure even though the remaining fault was inside the mounted client runtime.
- Resolution: stopped iterating on proxy guesses and traced the full chain end-to-end. The final fix kept the official image wrapper but made the build step patch two upstream client paths: `src/spa/entry.web.tsx` now honors `NEXT_PUBLIC_BASE_PATH` for the SPA basename, and `src/layout/GlobalProvider/useUserStateRedirect.ts` now strips/reapplies the configured base path before browser redirects. After rebuilding the custom image and recreating the app container, Safari reached `/chat/onboarding/classic`, completed onboarding, and entered the usable `/chat` homepage.
- Prevention: for mounted apps, do not stop at edge routing and auth success. If the browser reaches the shell but stalls after login, validate both router basename handling and browser-side `window.location` redirects under the mounted path before changing the proxy again.

- Problem: the auto-SSO bootstrap originally rewrote live `/chat/signin` HTML while leaving upstream compression headers intact, which is enough to turn a correct script injection into a broken response on the real browser path.
- Resolution: HTML mutation on the edge now drops stale `Content-Encoding`, `Content-Length`, `Transfer-Encoding`, and `ETag` before re-emitting the rewritten body, and the injected bootstrap calls the mounted `/chat/api/auth/sign-in/oauth2` endpoint instead of guessing a root-scoped auth path.
- Prevention: if a proxy mutates proxied HTML, response-header normalization is part of the feature, not cleanup. Never rewrite bodies on live traffic while preserving upstream compression or stale length metadata.

- Problem: route and onboarding success were not enough to prove the product actually worked; until a real provider-backed reply existed, `/chat` was still only “UI reachable,” not “assistant usable.”
- Resolution: reused the currently healthy DeepSeek key from the stock dashboard runtime, recreated `lobehub-app`, selected `DeepSeek V4 Pro` in a scripted browser session, and verified a real live reply on the public route: prompt `你好，请只回复“测试成功”。` returned `测试成功`.
- Prevention: for chat products, acceptance must include one minimal real model round-trip on the public route, not only successful login, onboarding, and homepage rendering.

- Problem: custom-image cold builds for this upstream monorepo are dominated by dependency download time, but the wrapper previously hid the upstream `USE_CN_MIRROR` capability, so operators had to remember undocumented environment tricks or accept slow default registry fetches.
- Resolution: the wrapper now transparently forwards `USE_CN_MIRROR` into `docker build`, documents the switch in `README.md`, and exposes a default-off toggle in `deploy/.env.example`.
- Prevention: when upstream already offers a practical build-acceleration control, surface it in the wrapper and docs instead of forcing future sessions to rediscover it from raw Dockerfiles.

- Problem: the dashboard task could be force-closed while the actual `https://hernando-zhao.cn/chat` product route was still not usable, which risks letting operators read board success as product success.
- Resolution: from this point, `lobechat` closeout is tracked separately from the board task lifecycle. Safari verification is now the product truth source: the board may be finished, but the product remains incomplete until `/chat` reaches a usable LobeHub UI instead of the app-shell `Loading` state.
- Prevention: for user-facing apps, do not let queue closeout become the acceptance signal. Record product/runtime truth separately in `PROJECT_STATUS.json`, and require a real browser success state on the public URL before calling the product complete.

- Problem: a temporary `window.__DEBUG_PROXY__` HTML injection made the stalled UI render, but only by flipping the upstream SPA into its hard-coded `/_dangerous_local_dev_proxy` development mode; the browser then escaped toward root-domain routes instead of staying canonically under `/chat`.
- Resolution: keep that result only as diagnostic evidence that client-side route interpretation is part of the `Loading` failure. Do not treat `__DEBUG_PROXY__` as a production basename knob or a valid `/chat` fix.
- Prevention: when a minified upstream bundle exposes an internal debug flag, prove whether it is a supported production surface before adopting it. A route hack that only works by entering a named debug-proxy code path is not a shippable subpath solution.

- Problem: the root-domain OIDC bridge had been described in repo docs before it actually existed in `port80-proxy.js`, and the live control plane still let root `/trpc/*` fall through unless a `/chat` referer proved ownership. Together those gaps made acceptance oscillate between “LobeHub local login page” and “TRPC Asset not found” even though the higher-level plan had already switched to shared identity.
- Resolution: the edge proxy now auto-redirects authenticated `/chat/signin` and root `/signin?callbackUrl=.../chat...` requests into `generic-oidc`, and the live control plane now treats root `/trpc/*` as always belonging to the `/chat` tunnel. The fixes were verified on the real domain: an authenticated redirect chain now reaches `https://hernando-zhao.cn/chat/` with HTTP 200 instead of stopping at the LobeHub email/password page.
- Prevention: for this wrapper, documentation changes about shared account behavior are not enough. Every auth/routing contract change must be paired with a real-domain redirect-chain check and at least one root-escaped app request check before the task is allowed back toward acceptance.

- Problem: 根域登录后访问 `/chat` 仍进入 LobeHub 自己的 Better Auth 登录页，说明入口层只做了访问控制，没有把根域账号变成 LobeHub 可消费的身份来源。
- Resolution: keep the official LobeHub image and move account unification to the root-domain edge: `port80-proxy.js` now acts as a minimal OIDC Provider backed by `hz_auth_session`, while LobeHub is configured as a `generic-oidc` client with email/password disabled.
- Prevention: when acceptance says “same domain account system,” do not treat an outer login gate plus an inner app login as sufficient. The app must consume the shared identity directly, usually through OIDC/SSO or an explicit session bridge.

- Problem: `/chat` could pass homepage and tool-catalog checks while the real browser still fell out of LobeHub through root-scoped `/signin`, `/_next/*`, and contextual `/api/*` paths.
- Resolution: keep LobeHub on the official image, and solve the subpath mismatch in the control-plane/edge route ownership layer: `/chat` stays the public alias, escaped root static assets and proven `/chat` auth/API context go back to the LobeHub tunnel, and unrelated control-plane root APIs remain owned by the control plane.
- Prevention: for official apps mounted under a main-site subpath, acceptance must include authenticated browser verification of the redirected login page and root-scoped assets, not only a curl check of the alias entry.

## 2026-04-27

- Problem: the remote control-plane release checkout for `lobechat` had drifted into a stale shell that no longer matched the maintained local wrapper, so project-create retries on the server kept seeing missing deploy assets even after the local repo had been repaired.
- Resolution: re-synced the maintained canonical wrapper into `/root/codex/release/lobechat` before retrying the control-plane task, so remote retries no longer execute against an incomplete release checkout.
- Prevention: when a project-create failure is caused by missing wrapper assets or deploy metadata drift, publish the canonical project checkout to the remote `release/<project>` root before expecting the server-side task state to recover.

- Problem: current upstream LobeHub images now reject the deprecated `NEXT_PUBLIC_AUTH_URL` variable, which left `lobehub-app` in a restart loop and kept `127.0.0.1:3210` unreachable even though the rest of the Compose stack was healthy.
- Resolution: removed `NEXT_PUBLIC_AUTH_URL` from the Compose wrapper, recreated the app container, and re-verified that the stack reaches a healthy local app which redirects unauthenticated traffic into the real-domain sign-in gate.
- Prevention: when refreshing an official-image deployment wrapper, re-run the current upstream image instead of assuming older environment variables remain valid; deprecated variables that turn into hard startup errors must be pruned from the wrapper in the same turn.

- Problem: the active acceptance checklist covered Compose, auth, chat flow, and `/chat` routing, but it still did not explicitly require operator discovery surfaces like the authenticated homepage and the control-plane tool catalog.
- Resolution: the acceptance contract now treats the authenticated homepage card and the `/middle` tool-entry listing as required user-facing checkpoints for `LobeChat`, not optional polish after the runtime itself works.
- Prevention: for user-facing projects on this platform, acceptance must cover both the runtime route and the operator-visible entry surfaces that are supposed to lead humans into that route.

- Problem: lobechat repo 已经积累了多份有效说明文档，但默认入口仍只有 README；新会话既看不出当前上线阶段，也容易在 `docs/` 下混读 active spec 和历史来源记录。
- Resolution: standardized this repo on `PROJECT_STATUS.json` + `README.md` + `PROJECT_RULES.md` + `DECISIONS.md` + `PROCESS.md`, moved active docs into `docs/contracts/`, and moved source-reference material into `docs/archive/`.
- Prevention: future routing/auth/operations work must update the canonical entry docs in the same turn; active operational specs stay in `docs/contracts/`, while historical notes and external source captures stay in `docs/archive/`.

## 2026-04-27

- Problem: 需求最初只写“LobeChat”，但实际目标是把 LobeHub 官方自托管方案落到本机 Mac，并挂到 `https://hernando-zhao.cn/chat`，同时复用或演进现有统一账号体系。
- Resolution: 项目定位为官方 Docker 镜像部署包装层，而不是自研聊天产品或重度源码分叉；一期先固定 Compose、持久化、账号策略、供应商配置、路由风险和验收手册。
- Prevention: 引入大型开源应用时，先区分“官方已支持能力”和“本域名/本账号/本运维拓扑需要适配的能力”，再决定是否修改上游源码。

## 2026-04-27

- Problem: project-create acceptance failed because this repo declared a descriptive but unsupported compose-only `.codex.deploy.json` mode.
- Resolution: the profile now uses the control plane's supported `local_runtime_service` mode and constrains it to sync/preserve/validate behavior for the Docker Compose wrapper.
- Prevention: deployment profiles must use only modes implemented by `local-control-server/local-deploy-runtime.js`; project-specific topology belongs in profile fields, docs, and post-sync commands, not in invented mode names.

## 2026-04-27

- Problem: the repo documentation and deploy profile already depended on `scripts/lobehubctl.sh`, but the tracked `scripts/` directory was missing, so resumed local-runtime publish paths could fail before execution with a missing-path error.
- Resolution: restored `scripts/lobehubctl.sh` with the documented compose validation, lifecycle, backup, restore, and secret-generation entrypoints, and revalidated `scripts/lobehubctl.sh config` against the current compose stack.
- Prevention: if README, operations docs, `.env.example`, or post-sync deploy commands reference a helper script, that script must be tracked in the repo and validated before declaring the deployment wrapper recoverable.

- Problem: Compose static validation still failed when only `deploy/.env.example` was available because service-level `env_file: .env` made the real secret file mandatory even for `docker compose config`.
- Resolution: the compose stack now receives all required LobeHub, provider, auth, proxy, and RustFS init variables through explicit `environment` entries, so `--env-file deploy/.env.example` can validate structure without creating a local secret file.
- Prevention: compose wrappers should distinguish required runtime secrets from static configuration validation; examples must be enough to run `docker compose config` without writing throwaway secret files.

- Problem: tunnel-backed local-runtime projects are assessed by the control-plane worker through `scripts/start-local-frontend.sh`, but the LobeHub wrapper only documented the compose helper.
- Resolution: keep `scripts/start-local-frontend.sh` in the project wrapper as the control-plane service entry that waits for Docker, starts the Compose stack, and keeps probing port 3210.
- Prevention: when a project advertises `localRuntime.frontendLocalPort`, the runtime start script is part of the deployable contract and must be versioned with the repo.
