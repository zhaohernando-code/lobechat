# 统一账号接入方案

## 当前落地策略

一期账号体系以 `hernando-zhao.cn` 根域统一登录为唯一用户入口：

- 根域入口层 `port80-proxy.js` 签发 `hz_auth_session`，并继续负责 `/chat` 访问前置登录。
- 同一个入口层提供最小 OIDC Provider：`/.well-known/openid-configuration`、`/oidc/authorize`、`/oidc/token`、`/oidc/userinfo`、`/oidc/jwks`。
- LobeHub 官方镜像不分叉，作为 `generic-oidc` client 接入根域 OIDC。
- 根域已登录用户访问 `/chat` 后，如果 LobeHub 需要认证，会由入口层自动发起 OIDC 授权，不进入 LobeHub 自己的邮箱密码登录页。

## LobeHub 配置

`deploy/.env` 中账号相关配置应保持：

```env
AUTH_ALLOWED_EMAILS=root@hernando-zhao.cn
AUTH_DISABLE_EMAIL_PASSWORD=1
AUTH_EMAIL_VERIFICATION=0
AUTH_TRUSTED_ORIGINS=https://hernando-zhao.cn
AUTH_SSO_PROVIDERS=generic-oidc
AUTH_GENERIC_OIDC_ID=lobehub
AUTH_GENERIC_OIDC_SECRET=<must match HZ_OIDC_CLIENT_SECRET>
AUTH_GENERIC_OIDC_ISSUER=https://hernando-zhao.cn
```

`AUTH_GENERIC_OIDC_SECRET` 是真实密钥，只能写入 `deploy/.env` 或服务器入口层环境，不写入 `.env.example`、README 或验收文档。

## 账号边界

- 一期只开放预置账号，不开放公网注册。
- LobeHub 邮箱密码登录关闭，避免形成第二套账号体系。
- 根域当前预置账号映射到 OIDC claims：`sub=hz-root`、`email=root@hernando-zhao.cn`。
- 后续少量新增用户时，应先把根域登录从单账号结构扩展为用户表，再由 OIDC claims 输出真实 `sub/email/name`；不要在 LobeHub 内单独新增邮箱密码用户。

## 验收规则

- 未登录根域访问 `/chat`，必须先回到根域统一登录页。
- 已登录根域访问 `/chat`，不得停留在 LobeHub 二次登录或注册页。
- `/chat/api/auth/callback/generic-oidc` 和必要的 root-escaped 回调必须回到 LobeHub 隧道，不得被控制面 `/api/auth/*` 抢占。
- LobeHub 内部仍使用自己的 Better Auth session cookie 保存应用会话，但该 session 必须由根域 OIDC 自动换取。

## 回滚

如果 OIDC 桥接异常，可以临时回滚到 LobeHub 邮箱密码模式：

```env
AUTH_DISABLE_EMAIL_PASSWORD=0
AUTH_SSO_PROVIDERS=
AUTH_GENERIC_OIDC_ID=
AUTH_GENERIC_OIDC_SECRET=
AUTH_GENERIC_OIDC_ISSUER=
```

回滚只用于应急排障；正式验收仍以根域统一登录后免二次登录为准。
