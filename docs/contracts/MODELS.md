# 模型接入与环境变量基线

一期模型目标是“配置口径统一、可见性可控、失败边界清楚”，不做供应商深度定制。

## OpenAI

```env
OPENAI_API_KEY=sk-...
OPENAI_PROXY_URL=https://api.openai.com/v1
OPENAI_MODEL_LIST=
```

如果本机网络无法直连 OpenAI，把 `OPENAI_PROXY_URL` 改成 OpenAI 兼容网关，并在验收中记录真实网关。

## OpenAI 兼容接口

兼容接口优先复用 OpenAI Provider 的代理地址和模型列表。验收要确认：

- Base URL 以 `/v1` 结尾。
- 支持 chat/completions 或 responses 的模型要在 LobeHub 中可见。
- 错误提示能区分密钥错误、模型不存在、网络不可达。

## Anthropic

```env
ANTHROPIC_API_KEY=sk-ant-...
ANTHROPIC_MODEL_LIST=
```

如走代理，需要在官方支持的 Anthropic base URL 环境变量上落地，不能混到 OpenAI 兼容地址里。

## Google Gemini

```env
GOOGLE_API_KEY=...
GOOGLE_MODEL_LIST=
```

Gemini 验收至少覆盖一个文本模型的普通对话和流式回复。

## DeepSeek

DeepSeek 作为一期国内兼容网关的指定目标：

```env
DEEPSEEK_API_KEY=...
DEEPSEEK_PROXY_URL=https://api.deepseek.com/v1
DEEPSEEK_MODEL_LIST=deepseek-chat,deepseek-reasoner
```

如果 LobeHub 当前镜像内置 DeepSeek Provider，则使用内置 Provider；若环境变量名随上游变化，需要以官方环境变量文档为准更新 `deploy/.env.example`。

