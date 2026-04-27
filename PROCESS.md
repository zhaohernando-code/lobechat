# PROCESS

## 2026-04-27

- Problem: lobechat repo 已经积累了多份有效说明文档，但默认入口仍只有 README；新会话既看不出当前上线阶段，也容易在 `docs/` 下混读 active spec 和历史来源记录。
- Resolution: standardized this repo on `PROJECT_STATUS.json` + `README.md` + `PROJECT_RULES.md` + `DECISIONS.md` + `PROCESS.md`, moved active docs into `docs/contracts/`, and moved source-reference material into `docs/archive/`.
- Prevention: future routing/auth/operations work must update the canonical entry docs in the same turn; active operational specs stay in `docs/contracts/`, while historical notes and external source captures stay in `docs/archive/`.

## 2026-04-27

- Problem: 需求最初只写“LobeChat”，但实际目标是把 LobeHub 官方自托管方案落到本机 Mac，并挂到 `https://hernando-zhao.cn/chat`，同时复用或演进现有统一账号体系。
- Resolution: 项目定位为官方 Docker 镜像部署包装层，而不是自研聊天产品或重度源码分叉；一期先固定 Compose、持久化、账号策略、供应商配置、路由风险和验收手册。
- Prevention: 引入大型开源应用时，先区分“官方已支持能力”和“本域名/本账号/本运维拓扑需要适配的能力”，再决定是否修改上游源码。
