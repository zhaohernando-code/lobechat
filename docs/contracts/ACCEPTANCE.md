# 验收清单

## 服务

- `scripts/lobehubctl.sh config` 通过。
- `scripts/lobehubctl.sh up` 后 `lobe`、`postgresql`、`redis`、`rustfs` 均为 running/healthy。
- `http://127.0.0.1:3210` 可访问。
- `https://hernando-zhao.cn/chat` 可访问，且 `/chat` 会规范化到 `/chat/`。
- 根域统一登录后，`/chat/` 必须自动完成 OIDC 桥接并进入 LobeHub 会话页面；不得停留在“登录或注册你的 LobeHub 账号”的二次登录页。
- LobeHub 生成的 root-scoped `/signin`、`/_next/*` 和上下文型 `/api/*` 请求必须被正确归属到 `/chat` 隧道，不能和根站控制面冲突。
- 统一登录主页 `https://hernando-zhao.cn/` 出现 LobeChat 入口卡片，并指向 `/chat`。
- 控制中台 `https://hernando-zhao.cn/middle` 的“工具入口”页出现 LobeChat 入口；入口必须能进入真实用户路由，而不是只停留在占位项目记录。

## 账号

- 非根域预置账号不能进入。
- 根域预置账号登录后能免二次登录进入 LobeHub。
- 注册不对任意公网用户开放。
- 退出登录后不能继续访问私人会话。

## 对话

- 能创建新会话。
- 能切换多个会话。
- 能看到流式输出。
- 页面刷新后会话和历史仍存在。
- 退出再登录后历史仍存在。

## 模型

- OpenAI 或 OpenAI 兼容接口至少一个模型可完成普通对话。
- Anthropic 至少一个模型可完成普通对话。
- Gemini 至少一个模型可完成普通对话。
- DeepSeek `deepseek-chat` 或 `deepseek-reasoner` 至少一个模型可完成普通对话。
- 密钥错误、模型错误、网络错误能在 UI 或日志中定位到供应商边界。

## 子路径

- 静态资源不请求到错误根路径。
- 登录 callback 不跳出 `/chat`。
- Cookie 不污染其他路径。
- SSE/流式输出不中断。
- 站内跳转不回到 `/` 或 `/middle`。

## 运维

- `scripts/lobehubctl.sh backup` 能产出 SQL 和数据归档。
- 停服务后重启，消息历史仍存在。
- Docker Desktop 重启后服务可恢复。
- 升级前有备份，升级失败可回滚镜像 tag 或恢复数据库。
