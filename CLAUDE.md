# lobechat

LobeHub 官方 Docker 镜像的本机部署包装。

**技术栈**：Docker Compose（LobeHub + PostgreSQL + Redis + RustFS + Searxng）

## 命令

```bash
bash scripts/lobehubctl.sh up        # 启动
bash scripts/lobehubctl.sh down      # 停止
bash scripts/lobehubctl.sh logs      # 日志
bash scripts/lobehubctl.sh backup    # 备份
bash scripts/lobehubctl.sh config    # 配置验证
```

## 已知陷阱

见根级 [KNOWN_TRAPS.md](../../KNOWN_TRAPS.md)。lobechat 是包装项目，主要风险在 Docker 状态和上游 LobeHub 版本锁定。

## 关键路径

| 文件 | 用途 |
|------|------|
| `docker-compose.yml` | 服务编排 |
| `scripts/lobehubctl.sh` | 管理脚本 |
| `docs/contracts/` | 合同文档（AUTH, ROUTING, MODELS 等） |

## 项目文档

见 PROJECT_STATUS.json、DECISIONS.md、PROCESS.md、PROJECT_RULES.md
