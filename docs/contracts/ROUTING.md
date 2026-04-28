# `/chat` 部署与路由蓝图

## 目标路径

- 用户入口：`https://hernando-zhao.cn/chat`
- 本机服务：`http://127.0.0.1:3210`
- 本机项目目录：`/Users/hernando_zhao/codex/projects/lobechat`
- 持久化目录：`/Users/hernando_zhao/codex/projects/lobechat/data`

## 当前内部落点

- `~/codex/projects/local-control-server/server.js` 已登记 `lobechat` 项目、内部工具入口 `/tools/lobechat` 和底层项目暴露路径 `/projects/lobechat`。
- 控制面当前已完成业务别名发布层修复：工具目录和首页入口可以把 `LobeChat` 指向 `/chat`，并在隧道代理时保留 `X-Forwarded-Host`、`X-Forwarded-Proto` 和 `X-Forwarded-Prefix`。
- 因此当前不要再把子路径问题误判为“控制面没有发布 `/chat`”。当前 live 验证显示，控制面和入口层已经能把 LobeHub 的 `/chat` 别名、`/signin` 登录页和 root-scoped `/_next/*` 静态资源送回同一个 LobeHub 隧道。

## 子路径风险

LobeHub 官方文档主要描述根路径域名或独立子域，例如 `https://lobehub.example.com`。`/chat` 是主站子路径，会影响：

- Next.js 静态资源路径。
- Better Auth 回调路径。
- Cookie `Path` / `Domain`。
- 站内重定向。
- SSE/流式输出和 WebSocket/Upgrade 头。
- S3 公网地址。

一期仍按“服务器入口层把 `/chat` 作为完整业务别名代理到 LobeHub 根路径”推进，但应用镜像本身现在必须使用 custom build，把 `NEXT_PUBLIC_BASE_PATH=/chat` 在构建期固化。当前不切换独立子域，也不做长期源码分叉；必要适配放在 custom image 构建、入口层和控制面项目代理中完成。

当前实测确认：stock image + 运行时 `NEXT_PUBLIC_BASE_PATH=/chat` 并不能稳定完成生产子路径挂载。官方文档要求对 `NEXT_PUBLIC_*` 做 custom build；否则即使入口层和控制面已处理 `/signin`、上下文型 `/api/*` 和部分 root-escaped 路径，前端仍可能卡在 shell `Loading` 或逃回根路径。控制面现在只把明确属于 LobeHub 上下文的路径转给 `/chat` 隧道，避免无条件抢占根站控制面的 `/api/*`。

## 入口代理要求

入口层代理到本机服务时必须保留：

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_buffering off;
proxy_cache off;
```

如果使用 Nginx 子路径代理，最小规则形态应类似：

```nginx
location = /chat {
    return 308 /chat/;
}

location /chat/ {
    proxy_pass http://127.0.0.1:3210/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-Prefix /chat;
    proxy_buffering off;
    proxy_cache off;
}
```

## 登录与回调

一期根域统一登录通过 OIDC 桥接给 LobeHub。入口层需要同时拥有这些路径：

- `/.well-known/openid-configuration`
- `/oidc/authorize`
- `/oidc/token`
- `/oidc/userinfo`
- `/oidc/jwks`

LobeHub OIDC callback 格式是：

```text
https://hernando-zhao.cn/chat/api/auth/callback/{provider}
```

其中一期 provider 为 `generic-oidc`。入口层必须允许 `https://hernando-zhao.cn/chat/api/auth/callback/generic-oidc`，并兼容上游偶发 root-escaped `/api/auth/callback/generic-oidc`，但不能无条件把所有根 `/api/auth/*` 都交给 LobeHub。

根域已登录用户如果命中 `/signin?callbackUrl=.../chat...` 或 `/chat/signin?...`，入口层应自动发起 LobeHub OIDC sign-in，而不是把 LobeHub 自己的登录/注册页展示给用户。若上游版本再次改变登录或静态资源路径生成规则，先在入口层和控制面代理中复核路径归属；只有无法安全区分 LobeHub 与控制面根路径时，才切换独立子域或上游支持的 base path 配置。

## S3 暴露

一期不验收上传，但 Compose 已保留 RustFS。若后续启用上传，`S3_PUBLIC_DOMAIN` 不能只填容器内地址，必须是浏览器和模型服务都能访问的公网地址。当前预留为：

```text
https://hernando-zhao.cn/chat-s3
```

这需要入口层另增 RustFS API 代理，且要配置 CORS。
