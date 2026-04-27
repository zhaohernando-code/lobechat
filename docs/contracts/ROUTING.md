# `/chat` 部署与路由蓝图

## 目标路径

- 用户入口：`https://hernando-zhao.cn/chat`
- 本机服务：`http://127.0.0.1:3210`
- 本机项目目录：`/Users/hernando_zhao/codex/projects/lobechat`
- 持久化目录：`/Users/hernando_zhao/codex/projects/lobechat/data`

## 子路径风险

LobeHub 官方文档主要描述根路径域名或独立子域，例如 `https://lobehub.example.com`。`/chat` 是主站子路径，会影响：

- Next.js 静态资源路径。
- Better Auth 回调路径。
- Cookie `Path` / `Domain`。
- 站内重定向。
- SSE/流式输出和 WebSocket/Upgrade 头。
- S3 公网地址。

一期建议优先按“服务器入口层把 `/chat` 作为完整业务别名代理到 LobeHub 根路径”推进，并保留验收风险。如果发现上游静态资源或回调强依赖根路径，立即切换为独立子域 `chat.hernando-zhao.cn` 或在服务器入口层做更深的 HTML/redirect 重写；不要修改 LobeHub 源码硬扛。

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

## 回调地址

Better Auth 默认回调格式是：

```text
https://hernando-zhao.cn/chat/api/auth/callback/{provider}
```

如果后续接 OIDC，IdP 中必须登记完整 `/chat` 前缀的 callback URL。若实测 LobeHub 仍生成根路径 callback，则不能在 `/chat` 子路径上线，必须改为独立子域或上游支持的 base path 配置。

## S3 暴露

一期不验收上传，但 Compose 已保留 RustFS。若后续启用上传，`S3_PUBLIC_DOMAIN` 不能只填容器内地址，必须是浏览器和模型服务都能访问的公网地址。当前预留为：

```text
https://hernando-zhao.cn/chat-s3
```

这需要入口层另增 RustFS API 代理，且要配置 CORS。

