# PROCESS

本文件只记录 LobeChat 部署包装可复用的反回归原则，不记录单次流水账。当前服务状态、发布证据、账号操作、生成文件和具体提交写入 `PROJECT_STATUS.json`、`DECISIONS.md`、release artifact、数据库备份记录或 git 历史。

## 维护规则

- **只写 mounted chat 产品的失败模式**：条目必须防止 future worker 在 auth、subpath、sidecar、MCP、storage、Docker 或 public route 验收上走错默认思路。单次修复和验证流水不写。
- **按主题维护，不按日期追加**：同类经验合并到主题；不要新增日期标题、commit、截图、文件名或一次性账号记录。
- **真实产品可用性优先**：能打开页面、登录成功或 schema 可见都不是最终原则；聊天产品必须能在 public route 完成真实模型/工具路径。
- **状态与原则分离**：`PROJECT_STATUS.json` 写当前健康和下一步，`DECISIONS.md` 写长期取舍，本文件写以后怎么不再错。

## Public Route 验收

- **聊天产品验收要有真实模型回合**：登录、onboarding、homepage render 只证明入口可达；至少一次 provider-backed reply 才能证明 assistant usable。
- **board closeout 不代表产品 ready**：控制面任务可以结束，但 `/chat` 产品仍以真实浏览器路由为最终 truth source。产品未 usable 时，要在状态文件显式保留差异。
- **移动端和成员账号要独立验收**：root 成功不代表 member 成功；桌面成功不代表移动可用。共享账号、静态资源、root-escaped API 和 browser-specific routing 都要覆盖真实用户路径。

## Mounted Path 与 Client Runtime

- **edge/auth 成功后仍要查 client basename**：如果浏览器到达 shell 后 loading 或跳错路径，优先验证 upstream router basename、`window.location` redirect、SPA entry 和 mounted base path，而不是继续猜 proxy。
- **不要把 debug flag 当生产合同**：上游 `__DEBUG_PROXY__`、`/_dangerous_local_dev_proxy` 或类似内部路径只能作为诊断证据。能让 UI 暂时渲染不代表可作为生产 subpath 方案。
- **root-escaped runtime 路由要归属明确**：`/_next`、`/_spa`、`/manifest.webmanifest`、`/api/auth/*`、`/api/user`、`/api/config` 等路径若属于 LobeChat，就必须由 edge/control proxy 明确转回 `/chat` surface，不能落入 control-plane root bucket。
- **proxy body mutation 必须处理压缩和 header**：注入 auto-SSO、rewrite URL 或修改 HTML/JSON/JS 时，先处理 content-encoding 和 magic bytes，并移除 stale length/cache/compression headers。

## Auth 与 Shared Identity

- **OIDC/PKCE 不能被服务端猜测替代**：当 upstream 在浏览器生成 PKCE state/challenge 时，不要伪造 server-side callback。保持 upstream 页面/endpoint 在可信路径内，只自动化最小用户动作或由 edge 启动官方 redirect。
- **root-domain identity 是唯一入口源**：自托管 `/chat` 若采用 root-domain OIDC，就不要再维护第二套 Better Auth email allowlist；成员准入应由根域账号系统决定。
- **官方 cloud skill 需要可信 client 凭证**：没有 Market trusted-client 配置时，不要启用会跳到官方 LobeHub OAuth 的 cloud skill。需要稳定能力时优先使用本地 skill/MCP。

## Search、MCP 与 Tooling

- **搜索健康要验证可用结果**：SearXNG 返回 200 JSON 不够；必须检查代表性中文/英文 query 有结果，并验证 LobeHub 使用的 Browserless/page-content 端点。
- **容器搜索出网路径要显式**：Mac 上的 containerized sidecar 不应依赖 LaunchAgent 环境继承；需要代理时把 host proxy path 写入配置和 health check。
- **本地 MCP 默认 stateless**：被 LobeHub 消费的本地 MCP 服务应 stateless，除非 client/server session lifecycle 已经持久化。重启后必须用同一个失败 topic 验证恢复，而不是只用 direct client。
- **工具 schema 可见不等于可执行**：custom MCP/plugin 显示在 UI 中不够；验收要有真实 tool-call audit log、output artifact 和 public download URL。
- **tool download URL 必须走 public edge**：本机文件存在和 MCP 成功不代表用户能下载。返回给浏览器的 URL 要从 `https://hernando-zhao.cn/chat-files/...` 等真实边缘路径验证。

## Storage 与 S3

- **Docker-only hostname 不能泄漏给浏览器**：RustFS、S3 presigned URL、skill zip 和 upload/download 路径必须 rewrite 到 public route；不要让 `rustfs:9000` 出现在浏览器可见链接里。
- **signed write 与 stale public read 分开处理**：skill zip 下载可以剥 stale query；presigned upload/object request 必须保留 `X-Amz-*` query 和 canonical host。不要用一个 rewrite 规则覆盖读写。
- **跨项目复用搜索只用数据边界**：其他项目需要 web search 时，边界应在 SearXNG/search result data。不要把 `/chat` 浏览器会话、agent memory 或 user state 当隐藏 executor。

## Docker 与数据目录

- **active Compose 数据目录必须绝对化**：PostgreSQL、Redis、RustFS 等数据路径不能依赖 checkout-relative `../data`。LaunchAgent 和 deploy profile 要指向 canonical data dir，避免 runtime helper 从错误目录启动新空库。
- **watcher 要拥有 Docker Desktop 启动**：Docker-backed release route 的 watch 不能只等待 Docker；需要能启动 Docker Desktop、记录不可用层级，并在 local probe 失败后重新进入 Compose/probe loop。
- **sidecar 健康要独立自愈**：homepage 可达不能证明 search、MCP、object storage 或 crawler 可用。watch/release health 应覆盖每个用户可见依赖边界。
