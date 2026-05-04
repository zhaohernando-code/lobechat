# LobeChat / LobeHub 本机部署项目

本项目不是重写 LobeChat，也不是维护一个脱离上游的 UI 分叉；它是 `https://hernando-zhao.cn/chat` 的本机部署包装层。应用主体继续使用 LobeHub 官方 Docker 镜像，当前一期目标是 Web 浏览器端、服务端数据库、登录鉴权、多会话、历史持久化和流式输出。

## Canonical docs

- `PROJECT_STATUS.json`: current phase, blockers, next step, and linked docs
- `README.md`: project定位、入口与运行方式
- `PROJECT_RULES.md`: repo-local约束与上线边界
- `DECISIONS.md`: durable deployment and scope decisions
- `PROCESS.md`: reusable lessons and anti-regression notes
- `docs/contracts/`: active auth, routing, operations, acceptance, and model docs
- `docs/archive/`: historical or source-reference material

## 当前判断

- 官方仓库已经从 `lobehub/lobe-chat` 迁移/重命名到 `lobehub/lobehub`；2026-04-27 重新核对 GitHub Releases 时，stable latest 为 `v2.1.51`（2026-04-16），同时存在更新的 canary / PR 测试构建，不作为生产基线。
- 官方当前 Docker Compose 文档推荐完整自托管栈：LobeHub 应用 + PostgreSQL、Redis、RustFS 和 Searxng。
- 官方文档同时明确说明：`NEXT_PUBLIC_*` 变量属于构建期覆盖项；如果要稳定支持 `/chat` 这类子路径，需要先构建 custom image，再由 Compose 运行，而不是指望 stock image 在运行时读取 `NEXT_PUBLIC_BASE_PATH`。
- LobeHub 官方支持多供应商模型接入、服务端 PostgreSQL、Better Auth、OIDC/SSO、文件/知识库、MCP/插件等能力；一期只验收对话主链路，不验收文件上传、知识库、插件市场和桌面端。
- 根域名入口层现在是一期统一账号源：`port80-proxy.js` 的 `hz_auth_session` 登录会话同时提供一个最小 OIDC Provider，LobeHub 作为 `generic-oidc` client 接入。
- LobeHub 邮箱密码登录已在一期禁用；用户通过根域统一登录后进入 `/chat` 时会自动发起 OIDC，不应再看到“登录或注册你的 LobeHub 账号”的二次登录页。

## 目录

- `deploy/docker-compose.yml`：本机常驻 Docker Compose 栈；应用镜像默认读取 `deploy/.env` 里的 `LOBEHUB_IMAGE`。
- `deploy/.env.example`：不含真实密钥的环境变量模板。
- `.codex.deploy.json`：控制面支持的 `local_runtime_service` 发布配置；用于同步包装层、保留本机数据/密钥，并在存在 `deploy/.env` 时校验 Compose。
- `scripts/lobehubctl.sh`：本机构建、启动、停止、日志、备份、校验入口。
- `scripts/start-local-frontend.sh`：控制面本机运行探针使用的前台服务守护脚本；负责拉起/等待 Docker Desktop，并确保 LobeHub Compose 栈启动。
- `docs/contracts/BASELINE.md`：官方能力与一期边界。
- `docs/contracts/ROUTING.md`：`/chat` 子路径和反向代理适配说明。
- `docs/contracts/AUTH.md`：根域 OIDC 桥接、预置账号和禁注册策略。
- `docs/contracts/MODELS.md`：OpenAI、OpenAI 兼容、Anthropic、Gemini、DeepSeek 配置基线。
- `docs/contracts/OPERATIONS.md`：上线、备份、恢复、升级和回滚手册。
- `docs/contracts/ACCEPTANCE.md`：准生产验收清单。
- `docs/archive/SOURCES.md`：上游信息源与历史检索记录。

## 本机运行

生成本地 `.env` 后先构建 custom image，再启动：

```bash
cd /Users/hernando_zhao/codex/projects/lobechat
cp deploy/.env.example deploy/.env
scripts/lobehubctl.sh secrets
scripts/lobehubctl.sh build-image
scripts/lobehubctl.sh config
scripts/lobehubctl.sh up
```

默认只监听本机回环端口：

- LobeHub: `http://127.0.0.1:3210`
- RustFS API: `http://127.0.0.1:9000`
- RustFS Console: `http://127.0.0.1:9001`

公网入口目标是 `https://hernando-zhao.cn/chat`。由于当前平台已有 `/projects/*` 隧道规范，但 `/chat` 是业务别名，最终上线需要服务器入口层增加一条 `/chat` 反向代理规则，详见 `docs/contracts/ROUTING.md`。

## 构建加速

首次冷构建会拉取上游 monorepo 依赖，耗时主要取决于 npm registry 网络质量。wrapper 现在直接透传上游已经支持的 `USE_CN_MIRROR` 开关：

```bash
cd /Users/hernando_zhao/codex/projects/lobechat
USE_CN_MIRROR=true scripts/lobehubctl.sh build-image
```

如果希望长期默认使用国内镜像，也可以把下面这行写进 `deploy/.env`：

```bash
USE_CN_MIRROR=true
```

说明：

- 这个开关只影响 `build-image` 阶段，不改变运行时 provider API 地址。
- 上游 Dockerfile 在 `USE_CN_MIRROR=true` 时会切到 `https://registry.npmmirror.com/`，并同步切换 `sentry-cli`、`canvas` 下载镜像。
- 如果你本机还有额外代理要求，继续配合 `HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY` 使用，不要把 provider 的代理地址和构建镜像源混为一类。

## Runtime watch

`com.codex.lobechat.frontend` points at `~/codex/projects/lobechat/scripts/start-local-frontend.sh` and must remain loaded with `RunAtLoad` + `KeepAlive`. The script starts Docker Desktop when the Docker daemon is unavailable, waits for Compose to become usable, starts the stack, and re-runs `scripts/lobehubctl.sh up` whenever `http://127.0.0.1:3210/` fails.

LobeHub has one persistent local data root: `~/codex/projects/lobechat/data`, exposed to Compose through `LOBE_DATA_DIR`. Do not run a second data root from `~/codex/runtime/projects/lobechat`; the helper script redirects accidental runtime calls back to the canonical project path.

The deploy profile must keep `restartLaunchAgents` and `healthChecks` aligned with that LaunchAgent and local port, otherwise a publish can appear successful without proving the watched release route is actually serving.

## Task closeout

- Default branch name: `task/lobechat/<yyyymmdd>-<slug>`
- Before calling work complete, update `DECISIONS.md`, `PROCESS.md`, and `PROJECT_STATUS.json` when the change affects durable decisions, reusable lessons, or current handoff state.
- Live-facing work is not complete until the compose stack or served `/chat` route has been rechecked through the real user-facing path that the change is meant to affect.

## 需要真实外部输入

这些内容不能自动生成，需要在正式上线前填入 `deploy/.env`：

- `AUTH_GENERIC_OIDC_SECRET`，必须和服务器入口层 `HZ_OIDC_CLIENT_SECRET` 一致。
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_API_KEY`
- `DEEPSEEK_API_KEY`
- 如国内网络访问 OpenAI/Anthropic/Gemini 需要代理，还需要配置对应代理或兼容网关地址。
