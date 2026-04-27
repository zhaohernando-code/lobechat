# 运维与上线手册

## 启动

```bash
cd /Users/hernando_zhao/codex/projects/lobechat
scripts/lobehubctl.sh config
scripts/lobehubctl.sh up
scripts/lobehubctl.sh ps
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
2. `scripts/lobehubctl.sh up`
3. 如果数据库迁移已破坏兼容性，使用升级前备份恢复。

生产升级前不要只使用 `latest` 做不可回滚升级；确认稳定版本后应 pin 到具体 tag。

## Mac 本机风险

- Docker Desktop 必须保持运行。
- Mac 不能休眠。
- 端口 `3210/54329/63790/9000/9001` 不能被占用。
- 服务器入口层到本机的隧道/代理必须持续在线。
- 证书续期在服务器入口层完成，不由本项目处理。
