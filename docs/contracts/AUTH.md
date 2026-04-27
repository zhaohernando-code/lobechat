# 统一账号接入方案

## 当前摸底结论

现有 `hernando-zhao.cn` 入口层确实有“统一登录页”的产品入口，但在当前可访问代码中没有一个可直接复用给 LobeHub 的账号服务：

- `local-control-server` 的 `config-runtime.js` 固定 `authMode = "disabled"`。
- `auth-runtime.js` 只保留本地 Bearer session 读取和退出，设备登录已退役。
- `state-store.js` 中的 `sessions` 表是控制面会话，不是用户账号表，也不是 OIDC Provider。
- 现有股票看板入口依赖服务器入口层鉴权/代理，而不是项目内部复用同一套用户表。
- `server.js` 里登记的 `lobechat` 只是项目元数据，不附带共享登录、OIDC 发行者或 `/chat` 访问控制。

## 一期落地策略

一期不改 LobeHub 源码，采用官方 Better Auth：

- `AUTH_ALLOWED_EMAILS` 写入预置用户邮箱清单。
- `AUTH_EMAIL_VERIFICATION=0`，因为一期不引入 SMTP。
- `AUTH_DISABLE_EMAIL_PASSWORD=0`，保留邮箱密码登录。
- 不配置开放注册入口的宣传或文档；账号新增由维护者更新 `AUTH_ALLOWED_EMAILS`，再让用户首次设置/登录。

这不是最终的“全域统一账号”，但它满足一期低用户量、可控白名单、服务端数据库会话的上线边界。

## 后续统一路径

要真正做到所有 `hernando-zhao.cn` 子应用共享账号，推荐把根域名登录改造成 OIDC Provider 或接入独立 IdP，然后 LobeHub 只作为 OIDC client：

```env
AUTH_SSO_PROVIDERS=generic-oidc
AUTH_GENERIC_OIDC_ID=lobehub
AUTH_GENERIC_OIDC_SECRET=<secret>
AUTH_GENERIC_OIDC_ISSUER=https://hernando-zhao.cn
AUTH_DISABLE_EMAIL_PASSWORD=1
```

实现时需要新增或确认：

- 统一用户表：`users(id, email, username, password_hash, role, disabled, created_at, updated_at)`。
- OIDC 客户端表：`oauth_clients(client_id, client_secret_hash, redirect_uris, scopes, disabled)`。
- 授权码/刷新令牌/session 表。
- 后台少量新增用户入口。
- 回滚策略：保留 LobeHub Better Auth 邮箱密码模式，OIDC 异常时可临时回退。

## 账号新增流程

一期新增用户：

1. 在 `deploy/.env` 的 `AUTH_ALLOWED_EMAILS` 增加邮箱。
2. 重启 `lobe` 服务。
3. 用户通过 `/chat` 登录。
4. 如后续启用邮箱验证或 OIDC，再迁移到统一后台维护。
