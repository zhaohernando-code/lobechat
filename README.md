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

- 官方仓库已经从 `lobehub/lobe-chat` 迁移/重命名到 `lobehub/lobehub`，GitHub 当前 latest release 显示为 `v2.1.52`（2026-04-20）。
- 官方当前 Docker Compose 文档推荐完整自托管栈：`lobehub/lobehub:latest`、PostgreSQL、Redis、RustFS 和 Searxng。
- LobeHub 官方支持多供应商模型接入、服务端 PostgreSQL、Better Auth、OIDC/SSO、文件/知识库、MCP/插件等能力；一期只验收对话主链路，不验收文件上传、知识库、插件市场和桌面端。
- 现有 `hernando-zhao.cn` 控制面代码中没有可直接复用给 LobeHub 的 OIDC/OAuth 账号源；`local-control-server` 目前是本地 `authMode=disabled`，它的 `sessions` 表不是统一身份系统。
- 因此一期采用 LobeHub 官方 Better Auth/数据库会话作为落地基线，并用 `AUTH_ALLOWED_EMAILS` 收敛到预置账号清单；真正“全域统一账号”需要后续把根域名登录改造成 OIDC Provider 或接入独立 IdP。

## 目录

- `deploy/docker-compose.yml`：本机常驻 Docker Compose 栈。
- `deploy/.env.example`：不含真实密钥的环境变量模板。
- `scripts/lobehubctl.sh`：本机启动、停止、日志、备份、校验入口。
- `docs/contracts/BASELINE.md`：官方能力与一期边界。
- `docs/contracts/ROUTING.md`：`/chat` 子路径和反向代理适配说明。
- `docs/contracts/AUTH.md`：账号体系摸底结论和一期策略。
- `docs/contracts/MODELS.md`：OpenAI、OpenAI 兼容、Anthropic、Gemini、DeepSeek 配置基线。
- `docs/contracts/OPERATIONS.md`：上线、备份、恢复、升级和回滚手册。
- `docs/contracts/ACCEPTANCE.md`：准生产验收清单。
- `docs/archive/SOURCES.md`：上游信息源与历史检索记录。

## 本机运行

生成本地 `.env` 后再启动：

```bash
cd /Users/hernando_zhao/codex/projects/lobechat
cp deploy/.env.example deploy/.env
scripts/lobehubctl.sh secrets
scripts/lobehubctl.sh config
scripts/lobehubctl.sh up
```

默认只监听本机回环端口：

- LobeHub: `http://127.0.0.1:3210`
- RustFS API: `http://127.0.0.1:9000`
- RustFS Console: `http://127.0.0.1:9001`

公网入口目标是 `https://hernando-zhao.cn/chat`。由于当前平台已有 `/projects/*` 隧道规范，但 `/chat` 是业务别名，最终上线需要服务器入口层增加一条 `/chat` 反向代理规则，详见 `docs/ROUTING.md`。

## Task closeout

- Default branch name: `task/lobechat/<yyyymmdd>-<slug>`
- Before calling work complete, update `DECISIONS.md`, `PROCESS.md`, and `PROJECT_STATUS.json` when the change affects durable decisions, reusable lessons, or current handoff state.
- Live-facing work is not complete until the compose stack or served `/chat` route has been rechecked through the real user-facing path that the change is meant to affect.

## 需要真实外部输入

这些内容不能自动生成，需要在正式上线前填入 `deploy/.env`：

- `AUTH_ALLOWED_EMAILS`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_API_KEY`
- `DEEPSEEK_API_KEY`
- 如国内网络访问 OpenAI/Anthropic/Gemini 需要代理，还需要配置对应代理或兼容网关地址。
