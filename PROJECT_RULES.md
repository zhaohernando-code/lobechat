# LobeChat Project Rules

- 本项目维护 LobeHub 官方镜像在本机 Mac 的部署、配置、运维和 `hernando-zhao.cn/chat` 上线适配；不要把它演变为 LobeHub 源码大分叉。
- 保持 canonical project docs 一致：`PROJECT_STATUS.json`、`README.md`、`PROJECT_RULES.md`、`DECISIONS.md`、`PROCESS.md`。
- 默认优先升级官方 Docker 镜像和官方 Compose 口径，只在子路径发布、账号复用、反向代理和本机持久化上做最小必要适配。
- 真实密钥只能写入 `deploy/.env` 或本机密钥管理位置；`deploy/.env.example`、文档和脚本不得包含真实 API Key、数据库密码或用户密码。
- 长期运行的数据目录固定在 `/Users/hernando_zhao/codex/projects/lobechat/data/`，由 `LOBE_DATA_DIR` 显式传给 Compose；备份默认写入 `backups/`。不要让 `runtime/`、worker 临时目录或其他 checkout 形成第二份 LobeHub 数据根。
- `/chat` 是用户入口；如果同时存在规范隧道路由，文档必须明确区分“用户入口”和“底层挂载/代理路径”。
- 账号策略必须保持“预置账号、禁开放注册”的边界；若后续接入统一 OIDC/SSO，必须同步更新 `docs/contracts/AUTH.md` 和根级入口文档。
- Durable deployment or scope decisions go to `DECISIONS.md`; reusable lessons go to `PROCESS.md`; current progress and blockers go to `PROJECT_STATUS.json`.
