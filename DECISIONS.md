# LobeChat Deployment Decisions

[2026-04-27T17:30:00+08:00] Canonical deployment-wrapper handoff decision:
This repo now uses `PROJECT_STATUS.json` as the first current-state handoff source, `DECISIONS.md` as the durable deployment and scope decision log, and `PROCESS.md` as the reusable lessons log. New sessions should not infer current readiness from scattered `docs/*` files alone.

补充说明
- Active operational specs live under `docs/contracts/`.
- Historical source-reference material lives under `docs/archive/`.
- The repo remains a deployment wrapper around the official LobeHub image rather than a long-lived fork of upstream product code.

[2026-04-27T17:30:00+08:00] Entry and auth boundary decision:
The user-facing target remains `https://hernando-zhao.cn/chat`, while the repo continues to distinguish that alias from the underlying routing and local compose runtime. Account strategy remains “pre-provisioned accounts only” until a real shared identity provider exists.
