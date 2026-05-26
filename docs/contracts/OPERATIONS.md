# 运维与上线手册

## 启动

```bash
cd /Users/hernando_zhao/codex/projects/lobechat
scripts/lobehubctl.sh build-image
scripts/lobehubctl.sh config
scripts/lobehubctl.sh up
scripts/lobehubctl.sh ps
```

`build-image` 会从 `deploy/.env` 指定的 `LOBEHUB_UPSTREAM_REPO` / `LOBEHUB_UPSTREAM_REF` 获取上游源码，并把 `NEXT_PUBLIC_BASE_PATH` 作为构建期参数固化进 `LOBEHUB_IMAGE`。这一步现在是 `/chat` 子路径部署的正式前置条件，不再依赖 stock image 的运行时环境变量覆盖。

首次启动前，`deploy/.env` 里至少要替换 `POSTGRES_PASSWORD`、`AUTH_SECRET`、`KEY_VAULTS_SECRET`、`RUSTFS_SECRET_KEY`，并确认 `AUTH_GENERIC_OIDC_SECRET` 与服务器入口层 `HZ_OIDC_CLIENT_SECRET` 一致。真实值不能写入 `.env.example` 或文档。

持久化数据根固定为：

```bash
/Users/hernando_zhao/codex/projects/lobechat/data
```

`scripts/lobehubctl.sh` 会默认导出 `LOBE_DATA_DIR` 指向这个目录，Compose 的 PostgreSQL、Redis、RustFS volume 都必须从这里挂载。不要从 `~/codex/runtime/projects/lobechat/data` 或 worker worktree 启动第二份数据根。

一期账号配置必须保持根域 OIDC 桥接：

```env
AUTH_DISABLE_EMAIL_PASSWORD=1
AUTH_SSO_PROVIDERS=generic-oidc
AUTH_GENERIC_OIDC_ID=lobehub
AUTH_GENERIC_OIDC_ISSUER=https://hernando-zhao.cn
```

## 日志

```bash
scripts/lobehubctl.sh logs lobe
scripts/lobehubctl.sh logs postgresql
scripts/lobehubctl.sh logs redis
scripts/lobehubctl.sh logs rustfs
```

## 备份

```bash
scripts/lobehubctl.sh backup
```

备份包括：

- PostgreSQL dump：`backups/lobehub-<timestamp>.sql`
- `data/` 归档：`backups/lobehub-data-<timestamp>.tar.gz`

## 恢复

数据库恢复：

```bash
scripts/lobehubctl.sh restore-db backups/lobehub-YYYYMMDD-HHMMSS.sql
```

数据目录恢复需要先停服务，再恢复归档：

```bash
scripts/lobehubctl.sh down
tar -C /Users/hernando_zhao/codex/projects/lobechat -xzf backups/lobehub-data-YYYYMMDD-HHMMSS.tar.gz
scripts/lobehubctl.sh up
```

## 升级

```bash
scripts/lobehubctl.sh backup
scripts/lobehubctl.sh pull
scripts/lobehubctl.sh up
```

升级后必须跑 `docs/contracts/ACCEPTANCE.md` 中的登录、会话、流式、刷新、重启恢复检查。

## 回滚

1. 在 `deploy/.env` 中把 `LOBEHUB_IMAGE_TAG` 改回上一个可用版本。
2. 如需更换上游版本，同时更新 `LOBEHUB_UPSTREAM_REF` 后重新执行 `scripts/lobehubctl.sh build-image`
3. `scripts/lobehubctl.sh up`
4. 如果数据库迁移已破坏兼容性，使用升级前备份恢复。

生产升级前不要只使用 `main` / `latest` 做不可回滚升级；确认稳定版本后应 pin 到具体 tag 或 commit。

## Mac 本机风险

- Docker Desktop 必须保持运行。
- Docker Desktop 资源建议至少 `8 GiB` 内存、`4` CPU、`2 GiB` swap；`4 GiB / 2 CPU` 可以启动主链路，但 Browserless 和搜索 sidecar 同时运行时容易放大延迟和恢复窗口。
- Mac 不能休眠。
- 端口 `3210/54329/63790/9000/9001` 不能被占用。
- 服务器入口层到本机的隧道/代理必须持续在线。
- 证书续期在服务器入口层完成，不由本项目处理。

## 自动恢复 watch

长期运行由 LaunchAgent `com.codex.lobechat.frontend` 管理，入口脚本固定为：

```bash
~/codex/projects/lobechat/scripts/start-local-frontend.sh
```

该脚本必须在后台 LaunchAgent 环境中自行设置 Docker CLI 的 `PATH`，并在 Docker daemon 不可用时主动执行 `open -g -a Docker`。只等待 `docker info` 不足以恢复 `/chat`，因为 Docker Desktop 退出后 Compose 的 `restart: unless-stopped` 不会有机会执行。

恢复检查：

```bash
launchctl print gui/$(id -u)/com.codex.lobechat.frontend
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
curl -I http://127.0.0.1:3210/
curl -fsS "http://127.0.0.1:18080/search?q=health-check&format=json" | head
curl -I https://hernando-zhao.cn/chat/
```

发布态健康检查不能只看首页是否有响应，还要覆盖根域 OIDC 登录桥接和本地 SearXNG JSON API：

```bash
~/codex/projects/lobechat/scripts/lobehubctl.sh health
~/codex/projects/lobechat/scripts/lobehubctl.sh health-search
```

`health` 会确认 `deploy/.env` 中 `APP_URL=https://hernando-zhao.cn`、`AUTH_DISABLE_EMAIL_PASSWORD=1`、`AUTH_SSO_PROVIDERS=generic-oidc`、`AUTH_GENERIC_OIDC_ID=lobehub`、`AUTH_GENERIC_OIDC_SECRET` 非空、`AUTH_GENERIC_OIDC_ISSUER=https://hernando-zhao.cn`、`SEARCH_PROVIDERS=searxng`、`CRAWLER_IMPLS`、`BROWSERLESS_URL` 和 `BROWSERLESS_TOKEN`，并 POST 本地 `/api/auth/sign-in/oauth2`，要求返回根域 `/oidc/authorize`。它还要求 `127.0.0.1:18080/search?...&format=json` 通过稳定英文搜索，并要求 `127.0.0.1:13000/content?token=...` 能抓取 `example.com`。中文财经搜索默认作为告警信号保留，因为上游搜索引擎会出现 CAPTCHA、解析变化或代理抖动；需要人工发布验收时可设置 `LOBE_STRICT_SEARCH_HEALTH=1` 让中文财经搜索失败阻断命令。`health-search` 探测搜索和爬取边界，方便把 web-search/crawl 退化和 `/chat` 首页故障分开定位。如果强制搜索健康检查失败，watch 会重建 `searxng` 容器；如果 OIDC/app 健康检查失败，watch 会重建 `lobe` 容器。
