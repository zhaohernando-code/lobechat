# 一期基线与现状调查

## 官方能力

LobeHub 当前已经具备这些一期需要的基础能力：

- Web 浏览器端应用，官方镜像可通过 Docker Compose 自托管。
- 服务端 PostgreSQL 数据库，保存用户、会话、消息、设置和认证数据。
- Redis 用于会话/缓存/限流等运行态能力。
- S3 兼容对象存储，官方当前文档默认 RustFS；一期不验收上传，但保留存储栈，避免后续迁移。
- RustFS 必须有健康检查，`rustfs-init` 必须等 RustFS healthy 后再创建 bucket；否则 LobeHub 可能早于对象存储初始化完成而启动。
- Better Auth 认证，支持邮箱密码、OAuth/OIDC、允许邮箱限制、禁用邮箱密码等配置。
- 多模型供应商配置，包含 OpenAI、Anthropic、Google、DeepSeek 和 OpenAI 兼容接口等。
- 流式输出、多会话、消息历史、移动端适配、PWA 等 LobeHub 产品能力。

## 一期范围

- 部署：Mac 本机 Docker Compose。
- 对外入口：`https://hernando-zhao.cn/chat`。
- 数据：PostgreSQL + Redis + RustFS 持久化到本项目 `data/`。
- 账号：一期复用根域统一登录，入口层提供 OIDC Provider，LobeHub 作为 `generic-oidc` client；禁用 LobeHub 邮箱密码登录，不开放任意注册。
- 模型：OpenAI / OpenAI 兼容、Anthropic、Google Gemini、DeepSeek。
- 验收：登录、创建会话、切换会话、流式回复、刷新恢复、重启恢复、备份恢复。

## 明确排除

- 不自研聊天 UI。
- 不做 LobeHub 大规模源码分叉；允许为 `NEXT_PUBLIC_BASE_PATH=/chat` 这类官方要求的构建期变量产出 custom image，但不长期维护产品逻辑分叉。
- 不验收文件上传、知识库/RAG、插件市场、MCP 市场、语音、绘图、桌面端。
- 不把 `local-control-server` 的 Bearer session 当成统一账号；统一账号桥接落在根域入口层 `port80-proxy.js`。

## 现有平台摸底

- `~/codex/CODEX.md` 定义当前拓扑：根域名 `/` 是统一登录页，控制面是 `/middle`，动态项目规范路径是 `/projects/<project-id>/`，业务入口可以有别名。
- `~/codex/projects/local-control-server/auth-runtime.js` 当前返回 `authMode=disabled`，不是统一身份系统；根域 `port80-proxy.js` 承担登录页、`hz_auth_session` 和 OIDC 发行者职责。
- `~/codex/projects/local-control-server/tool-runtime.js` 只内建 `/tools/*` 和 `/projects/*` 分发逻辑。
- `~/codex/projects/local-control-server/server.js` 已登记 `lobechat` 项目和 `/tools/lobechat`，但没有登记用户入口 `/chat` 或项目暴露路径。
- `~/.config/codex/project-tunnel.ashare-dashboard.env` 显示现有股票看板通过 SSH 反向隧道接到服务器，并由服务器入口层提供业务别名 `/stocks`。

结论：LobeHub 可以直接用官方 Docker 栈跑起来；本项目 Compose 已保留官方样例中的 RustFS 健康检查、bucket 初始化依赖、Redis 前缀/TLS 和 S3 兼容变量，同时继续把所有服务绑定到本机回环地址。但 `/chat` 业务别名、子路径资源、根域 OIDC 桥接、SSE/长连接代理需要服务器入口层配合，不是 LobeHub 官方镜像单独能解决的事情。
