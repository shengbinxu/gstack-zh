# Design 二进制深度解读

> 对应源码：[`design/src/`](https://github.com/garrytan/gstack/tree/main/design/src)
> AI 驱动的 UI 设计工具——从文字到像素级设计稿。

---

## 架构概览

Design 是一个**无状态 CLI 工具**（与 Browse 的守护进程模型不同），
通过 OpenAI Responses API 生成 UI 设计。

```
┌──────────────────────────────────────┐
│  CLI (cli.ts, 285 行)                │
│  ├─ 解析命令 + 参数                 │
│  ├─ 分发到 13 个命令 handler        │
│  └─ JSON 输出到 stdout              │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│  13 个命令                            │
│  ├─ generate   单张设计稿            │
│  ├─ variants   N 个风格/响应式变体   │
│  ├─ iterate    多轮迭代              │
│  ├─ check      视觉质量门            │
│  ├─ compare    HTML 对比板           │
│  ├─ diff       两张图的视觉差异      │
│  ├─ evolve     截图→改进设计稿      │
│  ├─ verify     设计稿 vs 实现截图    │
│  ├─ prompt     设计稿→实现指令      │
│  ├─ extract    设计稿→DESIGN.md     │
│  ├─ gallery    设计历史时间线        │
│  ├─ serve      反馈收集 HTTP 服务器  │
│  └─ setup      API key 配置          │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│  OpenAI API                           │
│  ├─ Responses API（图片生成）        │
│  ├─ GPT-4o Vision（质量检查/提取）   │
│  └─ previous_response_id（多轮）     │
└──────────────────────────────────────┘
```

---

## 核心工作流

### 1. 生成 → 变体 → 比较 → 迭代

```
$D generate --brief "深色仪表盘" --output mockup.png
      │
      ▼
$D variants --brief "..." --count 3 --output-dir variants/
      │  同时生成 3 个风格方向：
      │  默认 / 大胆 / 简约 / 温暖 / 专业 / 暗色 / 活泼
      │  交错启动（1.5s 间隔防限流）
      ▼
$D compare --images "variants/*.png" --serve
      │  生成 HTML 对比板，打开浏览器
      │  用户评分（1-5星）+ 文字反馈 + 选择偏好
      ▼
$D iterate --session session.json --feedback "更简约" --output v2.png
      │  用 previous_response_id 保持视觉上下文
      │  失败则回退到从头生成（含累积反馈）
      ▼
反复迭代直到满意
```

### 2. 设计 → 代码

```
$D extract --image approved.png
      │  GPT-4o 分析设计稿
      │  提取：颜色（hex）、排版（字体/大小/粗细）、间距、布局
      ▼
      → 更新 DESIGN.md

$D prompt --image approved.png
      │  生成开发者可用的实现指令
      │  "用 Flexbox，gap: 16px，主色 #2a7d2a..."
      ▼
      → 传给 /design-html 实现
```

---

## 关键设计决策

### 无状态 CLI + /tmp Session

每次调用独立。会话状态用 `/tmp/design-session-{PID}-{timestamp}.json` 持久化。

```json
{
  "id": "1234-1704067200000",
  "lastResponseId": "resp_abc",     // 用于多轮 threading
  "originalBrief": "深色仪表盘",
  "feedbackHistory": ["更简约", "加大标题"],
  "outputPaths": ["v1.png", "v2.png"],
  "createdAt": "2026-04-06T..."
}
```

### 多轮迭代的双层策略

```
Tier 1: Threading（previous_response_id）
  → 保持视觉上下文，API 记得上一版长什么样
  → 质量更高

Tier 2: Fallback 重新生成
  → Threading 失败时使用
  → 从原始 brief + 最近 5 条反馈重新构造 prompt
  → 反馈上限 5 条（防 prompt injection + token 浪费）
```

### 比较板：自包含 HTML + HTTP 反馈

```
compare.ts 生成 628 行自包含 HTML：
  - 图片作为 base64 嵌入（无外部依赖）
  - 每个变体：评分（1-5星）+ 文字反馈 + "More like this"
  - 全局反馈文本框 + 提交按钮

serve.ts 启动 HTTP 服务器：
  - 接收浏览器 POST 反馈 → 写入 feedback.json
  - 支持"重新生成"循环：feedback → 新变体 → reload HTML
  - 超时 10 分钟自动退出
```

### 视觉质量门（check.ts）

```
$D generate --brief "..." --check --retry 2
```

用 GPT-4o Vision 评估生成的设计稿：
1. 文字可读性（标签/标题清晰？拼写错误？）
2. 布局完整性（所有请求的元素都在？）
3. 视觉连贯性（看起来像生产 UI，不像 AI 画作？）

返回 PASS / FAIL: [具体问题]。FAIL 时自动重试。

---

## 源码结构

```
design/src/
├── cli.ts           [285行]  入口、命令分发
├── commands.ts       [82行]  命令注册表
├── auth.ts           [63行]  API key 解析（~/.gstack/openai.json）
├── brief.ts          [59行]  Brief 解析（文字 → prompt）
├── generate.ts      [160行]  单张图片生成
├── variants.ts      [249行]  N 个变体（风格/响应式）
├── iterate.ts       [196行]  多轮迭代（threading + fallback）
├── check.ts          [96行]  Vision 质量门
├── compare.ts       [628行]  HTML 对比板生成
├── serve.ts         [255行]  反馈收集 HTTP 服务器
├── gallery.ts       [251行]  设计历史时间线
├── evolve.ts        [151行]  截图 → 改进设计稿
├── diff.ts          [104行]  两张图视觉 diff
├── memory.ts        [202行]  设计语言提取 → DESIGN.md
├── design-to-code.ts [88行]  设计 → 实现指令
└── session.ts        [79行]  /tmp Session 管理
```

---

## 设计决策总结

| 决策 | 原因 |
|------|------|
| 无状态 CLI | 简单、可调试、无数据库 |
| /tmp Session | 跨命令状态，crash 不影响项目 |
| Threading + Fallback | 尽量保持视觉上下文 |
| 交错启动（1.5s） | 避免 API 429 限流 |
| Base64 嵌入 HTML | 单文件自包含，可分享 |
| 反馈上限 5 条 | 防 prompt injection |
| Vision 质量门 | 自动过滤低质量生成 |
