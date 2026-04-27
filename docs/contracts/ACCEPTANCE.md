# 验收清单

## 服务

- `scripts/lobehubctl.sh config` 通过。
- `scripts/lobehubctl.sh up` 后 `lobe`、`postgresql`、`redis`、`rustfs` 均为 running/healthy。
- `http://127.0.0.1:3210` 可访问。
- `https://hernando-zhao.cn/chat` 可访问，且 `/chat` 会规范化到 `/chat/`。

## 账号

- 非白名单邮箱不能进入。
- 白名单预置账号能登录。
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

