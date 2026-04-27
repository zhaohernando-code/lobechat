# 外部资料来源

本轮按 2026-04-27 可访问资料摸底：

- LobeHub GitHub 仓库：`https://github.com/lobehub/lobehub`
- 旧 LobeChat 仓库入口会重定向到 LobeHub：`https://github.com/lobehub/lobe-chat`
- Docker deployment 文档：`https://www.mintlify.com/lobehub/lobehub/self-hosting/docker`
- Authentication Setup 文档：`https://www.mintlify.com/lobehub/lobehub/self-hosting/authentication`
- Database Configuration 文档：`https://www.mintlify.com/lobehub/lobehub/self-hosting/database`
- GitHub Releases：`https://github.com/lobehub/lobehub/releases`，2026-04-27 核对 stable latest 为 `v2.1.51`，canary / PR build 不作为本项目生产基线。
- 旧 server-database Docker Compose 文档仍可作为 Casdoor/MinIO 迁移参考：`https://lobehub.com/docs/self-hosting/server-database/docker-compose`

关键信息：

- 官方当前 Docker Compose 推荐完整栈包含 LobeHub、PostgreSQL、Redis、RustFS、Searxng。
- 当前 Docker 镜像名按文档为 `lobehub/lobehub:latest`。
- Better Auth 是当前官方认证基线，支持邮箱密码、允许邮箱限制和多个 OAuth/OIDC Provider。
- PostgreSQL 是生产推荐数据库，LobeHub 会把用户、认证、会话、消息和文件元数据写入数据库。
