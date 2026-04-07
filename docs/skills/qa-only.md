# `/qa-only` 技能逐段中英对照注解

> 对应源文件：[`qa-only/SKILL.md`](https://github.com/garrytan/gstack/blob/main/qa-only/SKILL.md)（1010 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。
>
> **与 `/qa` 的核心区别**：`/qa-only` = **只报告，绝不修复**。没有 Phase 7-11，没有 Edit 工具，没有 git commit，没有测试框架引导。它的工作在生成报告时结束。如果你想直接修复 bug，用 `/qa`。

---

## Frontmatter（元数据区）

```yaml
---
name: qa-only
preamble-tier: 4
version: 1.0.0
description: |
  Report-only QA testing. Systematically tests a web application and produces a
  structured report with health score, screenshots, and repro steps — but never
  fixes anything. Use when asked to "just report bugs", "qa report only", or
  "test but don't fix". For the full test-fix-verify loop, use /qa instead.
  Proactively suggest when the user wants a bug report without any code changes.
  Voice triggers: "bug report", "just check for bugs".
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
  - WebSearch
---
```

**中文翻译**：

- **name**: 技能名。用户输入 `/qa-only` 触发。
- **preamble-tier: 4**: 与 `/qa` 相同，最高级别。需要完整的环境感知和上下文恢复能力。
- **version: 1.0.0**: 报告专用模式，比 `/qa`（v2.0.0）简单——不需要修复循环相关的版本演进。
- **description**: 只报告的 QA 测试。系统性测试 Web 应用，生成含健康分数、截图和复现步骤的结构化报告，**但永远不修复任何东西**。
- **allowed-tools**: 注意**没有 `Edit`**，也没有 `Grep` 和 `Glob`——这两者主要用于定位 bug 源码，`/qa-only` 不需要读源码。

> **设计原理：为什么要有 /qa-only？**
> 有时候你不想让 AI 修改代码。比如：做代码审查之前想先看看 bug 全貌；想把报告发给产品经理讨论优先级；应用在生产环境，不能随便提交 fix。`/qa-only` 是纯粹的"眼睛"——看、拍照、报告，仅此而已。

---

## /qa 与 /qa-only 对比一览

| 特性 | `/qa` | `/qa-only` |
|------|-------|------------|
| 测试（Phases 1-6）| ✅ 相同 | ✅ 相同 |
| 健康分数计算 | ✅ 相同 | ✅ 相同 |
| Diff-aware 模式 | ✅ | ✅ |
| Browse 守护进程 | ✅ | ✅ |
| 工作区清洁度检查 | ✅（必须干净）| ❌（不需要）|
| 测试框架引导 | ✅（Bootstrap B2-B8）| ❌ |
| Phase 7 Triage | ✅ | ❌ |
| Phase 8 Fix Loop | ✅ | ❌ |
| Phase 9 Final QA | ✅ | ❌ |
| TODOS.md 更新 | ✅ | ❌ |
| 回归测试生成 | ✅ | ❌ |
| WTF-Likelihood | ✅ | ❌ |
| git commit | ✅（每个修复一个）| ❌ |
| Edit 工具 | ✅ | ❌ |
| Grep/Glob 工具 | ✅（定位源码）| ❌ |
| 前后对比截图 | ✅（修复前后）| ❌（只有发现截图）|
| 三层 Tier | 控制修复范围 | 无（没有修复）|
| 用时 | 5-30 分钟 | 5-15 分钟 |

---

## {{PREAMBLE}} 展开区（Preamble Tier 4）

与 `/qa` 相同，Tier 4 包含全部通用指令：升级检查、环境初始化、Boil the Lake 原则、遥测提示、上下文恢复等。不再重复——详见 [/qa 注解的 Preamble 章节](./qa.md#preamble-展开区preamble-tier-4)。

关键差异：`/qa-only` 的 Preamble 中 telemetry 记录的 skill name 是 `"qa-only"` 而非 `"qa"`，用于区分使用统计。

---

## 核心声明：/qa-only 的身份定位

> **原文**：
> ```
> # /qa-only: Report-Only QA Testing
>
> You are a QA engineer. Test web applications like a real user — click everything,
> fill every form, check every state. Produce a structured report with evidence.
> NEVER fix anything.
> ```

**中文**：你是 QA 工程师。像真实用户一样测试 Web 应用——点击所有元素，填写所有表单，检查所有状态。生成含证据的结构化报告。**永远不修复任何东西。**

> **设计原理**：最后一句"NEVER fix anything"是整个技能的约束核心。它加了大写和粗体，因为 AI 天然倾向于"帮你解决问题"——但有时候"解决问题"本身就是问题（比如 code review 前改了代码，评审的基准就变了）。明确的约束比隐含的期望更可靠。

---

## Setup 阶段：参数解析

> **原文**：
> ```
> Parse the user's request for these parameters:
> | Target URL | (auto-detect or required) |
> | Mode | full | --quick, --regression baseline.json |
> | Output dir | .gstack/qa-reports/ |
> | Scope | Full app (or diff-scoped) |
> | Auth | None |
> ```

**中文**：注意与 `/qa` 对比——`/qa-only` 的参数表中**没有 Tier 参数**。因为 Tier 控制的是"修复哪些级别的 bug"，而 `/qa-only` 不修复任何 bug，Tier 概念在这里无意义。

`/qa-only` 的 Mode 参数：

| 模式 | 触发方式 | 说明 |
|------|---------|------|
| full | 默认（提供 URL 时）| 系统性访问所有可达页面 |
| --quick | 显式指定 | 30 秒冒烟测试 |
| --regression | `--regression baseline.json` | 与历史基线对比 |
| diff-aware | 在 feature 分支上不带 URL | 自动聚焦改动范围 |

---

## Browse 二进制检测

与 `/qa` 相同的检测逻辑：

```bash
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
B=""
[ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="..."
[ -z "$B" ] && B=~/.claude/skills/gstack/browse/dist/browse
if [ -x "$B" ]; then echo "READY: $B" else echo "NEEDS_SETUP" fi
```

**注意**：`/qa-only` 没有工作区清洁度检查——因为它根本不需要提交任何东西，工作区脏不脏无所谓。

---

## Prior Learnings 和 Test Plan Context

与 `/qa` 相同。在正式测试前，加载历史经验（learnings）和已有测试计划：

```bash
~/.claude/skills/gstack/bin/gstack-learnings-search --limit 10
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
ls -t ~/.gstack/projects/$SLUG/*-test-plan-*.md 2>/dev/null | head -1
```

历史 learning 的价值在于避免重复踩坑——如果上次发现某个页面需要特定 Cookie 才能访问，这次直接应用，不用重新摸索。

---

## 运行模式（Modes）

### Diff-Aware 模式

与 `/qa` 完全相同——自动分析 `git diff main...HEAD`，识别受影响页面，优先测试改动范围。这是 feature 分支上的主要模式。

```
Diff-Aware 测试流程（/qa-only）：

  git diff main...HEAD → 识别受影响文件
         │
         ▼
  ├── 控制器/路由 → 对应 URL
  ├── 视图/组件   → 对应页面
  ├── API 端点    → 直接 fetch 测试
  └── CSS 文件    → 受影响页面的样式
         │
         ▼
  检测本地应用（:3000 / :4000 / :8080）
         │
         ▼
  逐页测试 + 截图 + 控制台错误检查
         │
         ▼
  生成报告（不修复，不提交）
```

---

## Phases 1-6：QA 测试（与 /qa 相同）

`/qa-only` 的 Phases 1-6 与 `/qa` 完全相同。以下是简要回顾：

### Phase 1：初始化
定位 browse 二进制，创建 `.gstack/qa-reports/screenshots/` 目录，复制报告模板，启动计时器。

### Phase 2：认证
支持账号密码、Cookie 导入、2FA。密码始终写 `[REDACTED]`。

### Phase 3：定向（Orient）
```bash
$B goto <target-url>
$B snapshot -i -a -o "screenshots/initial.png"
$B links          # 导航结构
$B console --errors
```

### Phase 4：探索
每个页面的七项检查：视觉扫描、交互元素、表单、导航、状态、控制台、响应式。

### Phase 5：记录问题
发现即记录，不批量积累。每个问题必须有截图证据。

### Phase 6：收尾

1. 用加权公式计算健康分数
2. 写"Top 3 Things to Fix"（最严重的 3 个问题）
3. 控制台错误汇总
4. 填写报告元数据
5. 保存 `baseline.json`

---

## 健康分数计算（与 /qa 相同）

各类别从 100 分起扣：
- Critical → -25，High → -15，Medium → -8，Low → -3

加权平均：

| 类别 | 权重 |
|------|------|
| Console | 15% |
| Functional | 20% |
| Accessibility | 15% |
| UX | 15% |
| Links | 10% |
| Visual | 10% |
| Performance | 10% |
| Content | 5% |

`score = Σ (category_score × weight)`

---

## 重要规则（12 条，前 10 条与 /qa 相同）

前 12 条通用规则（含 /qa-only 专属规则 11-12）：

> **原文（规则 11-12，/qa-only 专属）**：
> ```
> 11. Never fix bugs. Find and document only. Do not read source code, edit files,
>     or suggest fixes in the report. Your job is to report what's broken, not fix it.
>     Use /qa for the test-fix-verify loop.
> 12. No test framework detected? Include in the report summary:
>     "No test framework detected. Run /qa to bootstrap one and enable regression
>     test generation."
> ```

**中文**：
- **规则 11（核心）**：永远不修复 bug。只发现和记录。不要读源代码，不要编辑文件，甚至不要在报告里建议怎么修复。你的工作是报告坏了什么，不是修它。要修复，请用 `/qa`。
- **规则 12**：如果没有测试框架，在报告摘要里写一句提示："未检测到测试框架。运行 `/qa` 可以一键引导安装并启用回归测试生成。"

> **设计原理：为什么规则 11 明确说"不要建议怎么修复"？**
> 如果报告里写了"可以通过修改 auth.ts 第 47 行来修复"，用户可能会把这当成 AI 的判断去照做。但 `/qa-only` 根本没有读源码，这种建议是没有根据的猜测。只有 `/qa` 读了源码、做了修复、跑了验证，才有资格给出具体的修复建议。

---

## 输出结构

> **原文**：
> ```
> Local: .gstack/qa-reports/qa-report-{domain}-{YYYY-MM-DD}.md
> Project-scoped: ~/.gstack/projects/{slug}/{user}-{branch}-test-outcome-{datetime}.md
>
> .gstack/qa-reports/
> ├── qa-report-{domain}-{YYYY-MM-DD}.md
> ├── screenshots/
> │   ├── initial.png
> │   ├── issue-001-step-1.png
> │   ├── issue-001-result.png
> │   └── ...
> └── baseline.json
> ```

**中文**：与 `/qa` 相比，`/qa-only` 的截图目录中**没有** `issue-NNN-before.png` 和 `issue-NNN-after.png`——因为没有修复，就没有前后对比。

报告内每个问题只包含：
- 问题 ID、标题、严重程度、类别
- 复现步骤
- 截图证据
- **没有** Fix Status、Commit SHA、Files Changed

---

## Capture Learnings

与 `/qa` 相同。测试过程中发现的非显而易见的模式、项目特有的坑、认证方式等，都记录为 learnings：

```bash
~/.claude/skills/gstack/bin/gstack-learnings-log \
  '{"skill":"qa-only","type":"TYPE","key":"SHORT_KEY",
    "insight":"DESCRIPTION","confidence":N,"source":"SOURCE",
    "files":["path/to/relevant/file"]}'
```

Learning 类型：`pattern`（可复用方案）、`pitfall`（坑）、`preference`（用户偏好）、`architecture`（结构决策）、`tool`（框架洞察）、`operational`（环境/CLI/工作流知识）。

---

## 完整流程总结图

```
用户输入 /qa-only
     │
     ▼
┌─────────────────────────────────┐
│  Preamble（Tier 4）             │
│  ├── 升级检查 / 遥测 / 分支名  │
│  ├── Boil the Lake 原则        │
│  └── Context Recovery          │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Setup 阶段                     │
│  ├── 解析参数（URL / Mode）     │
│  │   注意：无 Tier 参数         │
│  ├── Browse 二进制检测          │
│  └── 无工作区清洁度检查         │
│      （不需要提交，所以无所谓）  │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Prior Learnings 加载           │
│  Test Plan Context 查找         │
└──────────────┬──────────────────┘
               │
     ┌─────────┴─────────┐
     │                   │
     ▼                   ▼
Diff-Aware 模式      Full 模式
(feature branch)     (URL provided)
     │                   │
     └─────────┬─────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Phases 1-6：QA 测试            │
│  Phase 1: 初始化                │
│  Phase 2: 认证                  │
│  Phase 3: 定向（Orient）        │
│  Phase 4: 探索（每页7项检查）   │
│  Phase 5: 记录问题（即时写入）  │
│  Phase 6: 健康分数计算          │
│           baseline.json 保存    │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  生成报告（Report Only）        │
│  ├── 本地: .gstack/qa-reports/  │
│  └── 项目级: ~/.gstack/projects │
│                                 │
│  ⛔ 没有 Phase 7 Triage         │
│  ⛔ 没有 Phase 8 Fix Loop       │
│  ⛔ 没有 Phase 9 Final QA       │
│  ⛔ 没有 TODOS.md 更新          │
│  ⛔ 没有 git commit             │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Learnings 记录                 │
│  Telemetry 上报                 │
└─────────────────────────────────┘
```

---

## 设计核心思路总结

| 设计决策 | 原因 | 关键约束 |
|---------|------|---------|
| 无 Edit 工具 | 报告专用模式，不改代码 | allowed-tools 中不含 Edit |
| 无 Grep/Glob 工具 | 不读源码，不定位 bug 来源 | 只从用户视角测试 |
| 无工作区清洁度检查 | 不产生 git commit，工作区脏不影响结果 | 设计有意省略 |
| 无 Tier 参数 | Tier 控制修复范围，报告模式不修复 | "Never fix anything" |
| 无测试框架引导 | 引导目的是生成回归测试，报告模式用不到 | 只有 /qa 有 B2-B8 |
| 无 WTF-Likelihood | 没有修复循环就不需要熔断机制 | Fix Loop 专有的安全机制 |
| 规则 11 禁止建议修复方案 | 未读源码的修复建议是不负责任的猜测 | "do not suggest fixes in the report" |
| 规则 12 提示测试框架 | 引导用户从 /qa-only 升级到 /qa | 缺少测试框架时的 upsell |
| 与 /qa Phase 1-6 完全相同 | 测试本身的标准不因是否修复而降低 | 相同的健康分数公式和权重 |
| 输出格式基本相同（无 before/after）| 方便将来升级为 /qa 对比查看 | baseline.json 完全兼容 |
