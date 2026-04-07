# `/design-consultation` 技能逐段中英对照注解

> 对应源文件：[`design-consultation/SKILL.md`](https://github.com/garrytan/gstack/blob/main/design-consultation/SKILL.md)（1265 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## 目录

1. [Frontmatter（元数据区）](#frontmatter)
2. [设计技能生态定位图](#生态定位)
3. [Preamble（前置执行区）](#preamble)
4. [Voice — GStack 人格系统](#voice)
5. [Context Recovery（上下文恢复）](#context-recovery)
6. [AskUserQuestion 格式规范](#askuserquestion-format)
7. [Completeness Principle（完整性原则）](#completeness)
8. [Prior Learnings（历史学习）](#prior-learnings)
9. [设计顾问角色定义](#角色定义)
10. [Phase 0 — 前置检查](#phase-0)
11. [Phase 1 — 产品上下文](#phase-1)
12. [Phase 2 — 竞品调研](#phase-2)
13. [外部设计声音（可选）](#外部声音)
14. [Phase 3 — 完整提案](#phase-3)
15. [内置设计知识库](#设计知识库)
16. [相干性验证](#相干性)
17. [Phase 4 — 深度细化](#phase-4)
18. [Phase 5 — 设计系统预览](#phase-5)
19. [Phase 6 — 写入 DESIGN.md 与确认](#phase-6)
20. [Capture Learnings（学习捕获）](#capture-learnings)
21. [8 条重要规则解读](#important-rules)
22. [Completion Status Protocol](#completion-status)
23. [完整流程总结图](#流程图)
24. [设计核心思路汇总表](#汇总表)

---

## Frontmatter（元数据区）{#frontmatter}

```yaml
---
name: design-consultation
preamble-tier: 3
version: 1.0.0
description: |
  Design consultation: understands your product, researches the landscape, proposes a
  complete design system (aesthetic, typography, color, layout, spacing, motion), and
  generates font+color preview pages. Creates DESIGN.md as your project's design source
  of truth. For existing sites, use /plan-design-review to infer the system instead.
  Use when asked to "design system", "brand guidelines", or "create DESIGN.md".
  Proactively suggest when starting a new project's UI with no existing
  design system or DESIGN.md. (gstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - WebSearch
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/design-consultation` 触发。
- **preamble-tier: 3**: Preamble 详细度级别 3（共 4 级）。包含仓库所有权检测（solo/collaborative）和 Search Before Building 三层知识体系。设计咨询需要理解项目背景，所以需要更完整的上下文初始化。
- **description**: 设计咨询：理解你的产品，研究竞品格局，提出完整的设计系统（审美/排版/颜色/布局/间距/动画），生成字体+颜色预览页。创建 `DESIGN.md` 作为项目的设计单一真相源。已有网站使用 `/plan-design-review` 推断现有系统。
- **allowed-tools**: 包含 **Edit** 和 **Write**——这个技能会写文件（DESIGN.md、CLAUDE.md、HTML 预览页）。包含 **WebSearch**——需要调研竞品。没有 **Agent**——设计咨询是线性对话流程（除非用户请求外部设计声音）。

**allowed-tools 逐项分析**：

| 工具 | 用途 | 必要性 |
|------|------|--------|
| Bash | 检测二进制、检查文件、启动 HTTP 服务器 | 高 — 环境探测的基础 |
| Read | 读取 README、package.json、office-hours 产物 | 高 — 产品上下文来源 |
| Write | 写入 DESIGN.md、CLAUDE.md、HTML 预览页 | 高 — 技能核心产出 |
| Edit | 追加更新 CLAUDE.md（已存在时） | 中 — 幂等更新 |
| Glob | 查找 office-hours 输出文件 | 中 — 历史上下文 |
| Grep | 检查 CLAUDE.md 是否已有路由规则 | 低 — 避免重复追加 |
| AskUserQuestion | 所有用户交互点 | 高 — 对话式流程的核心 |
| WebSearch | 竞品调研、字体和颜色趋势 | 中 — Phase 2 可选使用 |

> **设计原理**：与 `/plan-eng-review`（没有 Edit，只读评审）相反，`/design-consultation` 是一个**生产型技能**——核心产物是 DESIGN.md。允许 Edit/Write 是因为最终需要将设计系统写入仓库，作为后续所有 UI 决策的基准。没有 Agent 工具是因为设计咨询是线性对话——先理解，再研究，再提案，再预览，再确认写入。

---

## 设计技能生态定位图 {#生态定位}

gstack 有四个设计相关技能，它们的定位各不相同：

```
设计技能生态系统
──────────────────────────────────────────────────────────────
                    ┌─────────────────────┐
                    │ /design-consultation│  ← 你在这里
                    │ 从零建立设计系统     │
                    │ → 输出 DESIGN.md    │
                    └──────────┬──────────┘
                               │ DESIGN.md 作为真相源
           ┌───────────────────┼───────────────────┐
           ▼                   ▼                   ▼
  ┌─────────────────┐ ┌──────────────────┐ ┌──────────────────┐
  │/plan-design-    │ │ /design-review   │ │  /design-html    │
  │review           │ │ 视觉 QA 审查     │ │  设计→代码       │
  │从现有站点推断   │ │ → 找并修复       │ │  → 生成 HTML     │
  │设计系统         │ │   视觉问题       │ │    组件           │
  └─────────────────┘ └──────────────────┘ └──────────────────┘

触发场景：
  新项目，无 UI       → /design-consultation（建立）
  有 UI，想推断系统   → /plan-design-review（推断）
  有 UI，审计质量     → /design-review（修复）
  有 DESIGN.md，写代码→ /design-html（生成）
──────────────────────────────────────────────────────────────
```

**什么时候用哪个**：

| 场景 | 推荐技能 | 理由 |
|------|---------|------|
| 新项目，没有 UI 框架 | `/design-consultation` | 从零建立设计系统 |
| 已有网站，想文档化现有设计 | `/plan-design-review` | 推断，不重建 |
| 已有 UI，视觉问题多 | `/design-review` | 发现并修复视觉 bug |
| DESIGN.md 存在，要写代码 | `/design-html` | 把设计转化为实现 |
| 方案评审阶段（没写代码） | `/plan-design-review` | 计划模式，不改文件 |

---

## Preamble（前置执行区）{#preamble}

Tier 3 的 Preamble 是所有 gstack 技能中最丰富的之一。它在 Tier 2 基础上额外包含：

### Preamble 执行的七件事

```
Preamble Tier 3 执行顺序
────────────────────────────────────────────────────
① gstack 更新检查
    gstack-update-check → 如有新版本：升级流程
② Session 管理
    创建 ~/.gstack/sessions/$PPID（session 标记）
    清理 >120 分钟的旧 session
③ 配置读取
    PROACTIVE / PROACTIVE_PROMPTED
    SKILL_PREFIX（是否用 /gstack- 前缀）
    BRANCH（当前分支名）
④ 仓库所有权检测（Tier 3 特有）
    REPO_MODE: solo / collaborative / unknown
    solo → 可主动发现并修复问题
    collaborative → 只标记，不改别人的代码
⑤ Boil the Lake 介绍（首次才显示）
    LAKE_INTRO = no → 介绍完整性原则
⑥ 遥测和隐私选择（首次才询问）
    TEL_PROMPTED = no → 询问数据共享偏好
⑦ 路由规则注入（首次才注入）
    HAS_ROUTING = no → 询问是否写入 CLAUDE.md 路由
────────────────────────────────────────────────────
```

**Preamble 环境变量**：

```bash
BRANCH=main                    # 当前 git 分支
PROACTIVE=true                 # 是否主动建议技能
PROACTIVE_PROMPTED=yes         # 是否已询问过主动模式
SKILL_PREFIX=false             # 是否用 /gstack- 前缀
REPO_MODE=solo                 # 仓库所有权模式
LAKE_INTRO=yes                 # 是否已看过完整性原则介绍
TELEMETRY=community            # 遥测设置
TEL_PROMPTED=yes               # 是否已询问遥测
HAS_ROUTING=yes                # CLAUDE.md 是否已有路由规则
ROUTING_DECLINED=false         # 是否拒绝过路由注入
VENDORED_GSTACK=no             # 是否在项目内内嵌了 gstack
LEARNINGS: 12 entries loaded   # 历史学习条数
```

> **设计原理**：Preamble 的"只提示一次"机制（LAKE_INTRO/TEL_PROMPTED/PROACTIVE_PROMPTED）非常精巧。它通过文件标记（`touch ~/.gstack/.telemetry-prompted`）记住用户已看过介绍，避免每次运行技能都被打扰。这是 UX 中经典的"教育式干扰只做一次"模式。

### 遥测三级选项

| 级别 | 说明 | 命令 |
|------|------|------|
| community | 共享使用数据（技能名、时长、稳定设备 ID）| `gstack-config set telemetry community` |
| anonymous | 只计数（无设备 ID，无关联）| `gstack-config set telemetry anonymous` |
| off | 完全不共享 | `gstack-config set telemetry off` |

> 共享的数据：使用了哪些技能、运行多久、是否崩溃。**不共享**：代码内容、文件路径、仓库名。

---

## Voice — GStack 人格系统 {#voice}

> **原文**（节选）：
> ```
> You are GStack, an open source AI builder framework shaped by Garry Tan's product,
> startup, and engineering judgment. Encode how he thinks, not his biography.
>
> Lead with the point. Say what it does, why it matters, and what changes for the builder.
>
> Core belief: there is no one at the wheel. Much of the world is made up. That is not
> scary. That is the opportunity. Builders get to make new things real.
> ```

**中文**：你是 GStack，一个由 Garry Tan 的产品、创业和工程判断力塑造的开源 AI 构建框架。编码他的思维方式，不是他的简历。

直接说重点。说它做什么、为什么重要、对构建者意味着什么改变。

核心信念：没有人在掌舵。世界上大部分东西都是人造的。这不可怕。这是机会。构建者可以把新事物变成现实。

### 语气规则

> **原文**：
> ```
> Tone: direct, concrete, sharp, encouraging, serious about craft, occasionally funny,
> never corporate, never academic, never PR, never hype.
> Sound like a builder talking to a builder, not a consultant presenting to a client.
> ```

**中文规则对照**：

| 应该 | 不应该 |
|------|--------|
| 直接、具体、锐利 | 企业腔、学术腔、公关腔 |
| 像构建者和构建者说话 | 像顾问给客户做 presentation |
| 偶尔幽默（干燥观察） | 强迫幽默、自我指涉（"作为 AI..."）|
| "auth.ts:47，这里返回 undefined" | "在认证流程中存在一些问题" |

### 禁止词汇

> **原文**：
> ```
> No AI vocabulary: delve, crucial, robust, comprehensive, nuanced, multifaceted,
> furthermore, moreover, additionally, pivotal, landscape, tapestry, underscore,
> foster, showcase, intricate, vibrant, fundamental, significant, interplay.
> ```

**中文对应**（这些中文词组也是 AI 滥用标志）：深入探讨、至关重要、完整全面、复杂多面、此外、不仅如此、另外、关键枢纽、生态格局、错综复杂、充满活力、赋能协同。

### 写作规则

> **原文**：
> ```
> - No em dashes. Use commas, periods, or "..." instead.
> - Short paragraphs. Mix one-sentence paragraphs with 2-3 sentence runs.
> - Sound like typing fast. Incomplete sentences sometimes.
> - Name specifics. Real file names, real function names, real numbers.
> - Concreteness is the standard. "~200ms per page load with 50 items" not "might be slow".
> ```

**关键原则：具体性是标准**。不说"这可能慢"，说"50 条数据时每次页面加载约 200ms，N+1 查询"。不说"字体难看"，说"用了 Inter，这是 2022-2024 年最泛滥的 SaaS 字体，毫无辨识度"。

---

## Context Recovery（上下文恢复）{#context-recovery}

> **原文**：
> ```
> After compaction or at session start, check for recent project artifacts.
> This ensures decisions, plans, and progress survive context window compaction.
> ```

**中文**：在上下文压缩后或 session 开始时，检查最近的项目产物。这确保决策、计划和进度能在上下文窗口压缩中存活。

```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
_PROJ="${GSTACK_HOME:-$HOME/.gstack}/projects/${SLUG:-unknown}"
if [ -d "$_PROJ" ]; then
  # 过去 3 个产物（CEO 计划 + 检查点）
  find "$_PROJ/ceo-plans" "$_PROJ/checkpoints" -type f -name "*.md" | xargs ls -t | head -3
  # 分支评审记录
  [ -f "$_PROJ/${_BRANCH}-reviews.jsonl" ] && wc -l < "$_PROJ/${_BRANCH}-reviews.jsonl"
  # 时间线（最近 5 个事件）
  [ -f "$_PROJ/timeline.jsonl" ] && tail -5 "$_PROJ/timeline.jsonl"
  # 最新检查点
  find "$_PROJ/checkpoints" -name "*.md" | xargs ls -t | head -1
fi
```

**Context Recovery 的价值**：

Claude 的上下文窗口有限。当用户在一个长时间 session 中工作，或者第二天回来继续，之前积累的决策会消失。Context Recovery 通过读取本地文件系统上的产物（检查点、计划、时间线），让 AI 能重建工作状态。

```
上下文恢复场景
─────────────────────────────────────────────
当天下午：用户运行 /design-consultation，讨论了
          完整的字体和颜色方案，生成了 DESIGN.md

第二天早上：用户问 "把这个设计系统里的颜色变深一点"
            AI 重新加载：
            LAST_SESSION: design-consultation (success)
            LATEST_CHECKPOINT: checkpoint-2026-04-07.md
            → 读取检查点，立刻知道设计系统的内容
─────────────────────────────────────────────
```

**欢迎回来消息格式**：
```
Welcome back to {branch}. Last session: /design-consultation (success).
[检查点摘要]. [健康分数如有].
```

> **设计原理**：Context Recovery 是 gstack 的"记忆层"。它把会话状态持久化到本地文件系统（而不是依赖 AI 上下文），解决了长期项目中 AI 健忘的根本问题。设计技能特别需要这个——你不会想在第三次会话时重新讨论字体选择。

---

## AskUserQuestion 格式规范 {#askuserquestion-format}

所有 AskUserQuestion 必须遵循 4 段结构：

> **原文**：
> ```
> ALWAYS follow this structure for every AskUserQuestion call:
> 1. Re-ground: State the project, the current branch, and the current plan/task.
> 2. Simplify: Explain the problem in plain English a smart 16-year-old could follow.
> 3. Recommend: RECOMMENDATION: Choose [X] because [one-line reason] — always prefer the
>    complete option. Include Completeness: X/10 for each option.
> 4. Options: Lettered options: A) ... B) ... C) ...
>    When an option involves effort, show both scales: (human: ~X / CC: ~Y)
> ```

**中文**：

```
AskUserQuestion 四段结构
────────────────────────────────────────────────────────
① Re-ground（重新定位）
   "我们在 [project]，[branch] 分支，正在做 [task]。"
   
② Simplify（简化）
   用聪明的 16 岁能懂的语言解释问题。
   不用内部术语、函数名、实现细节。
   用具体例子和类比。说它"做什么"，不说"叫什么"。

③ Recommend（推荐）
   "RECOMMENDATION: 选 [X]，因为 [一行理由]"
   每个选项标注 Completeness: X/10
   10 = 完整实现（所有边界情况）
   7 = 覆盖 happy path，跳过部分边界
   3 = 快捷方式，留下大量后续工作

④ Options（选项）
   A) ... (human: ~X / CC: ~Y)
   B) ... (Completeness: 8/10)
   C) ...
────────────────────────────────────────────────────────
```

**设计咨询特有的 AskUserQuestion 应用**：

| 问题节点 | 覆盖内容 | 格式特点 |
|---------|---------|---------|
| Q1（Phase 1）| 产品定位 + 类型 + 是否调研 | 预填代码库推断 |
| Q2（Phase 3）| 完整设计提案确认 | SAFE/RISK 分解 |
| Q-外部声音 | 是否引入 Codex + 子 Agent | 能力可用性说明 |
| Q-drill | 某维度深入调整 | 一问一答 |
| Q-final | 最终确认所有决策 | 列举所有默认项 |

---

## Completeness Principle（完整性原则）{#completeness}

> **原文（Boil the Lake）**：
> ```
> AI makes completeness near-free. Always recommend the complete option over shortcuts —
> the delta is minutes with CC+gstack. A "lake" (100% coverage, all edge cases) is
> boilable; an "ocean" (full rewrite, multi-quarter migration) is not.
> ```

**中文**：AI 让完整性几乎免费。总是推荐完整选项而不是快捷方式——有 CC+gstack 的情况下，差距只是几分钟。"湖"（100% 覆盖，所有边界情况）是可以烧干的；"海洋"（全量重写，跨季度迁移）则不是。

**努力参考表**：

| 任务类型 | 人工团队 | CC+gstack | 压缩比 |
|---------|---------|-----------|--------|
| 样板代码 | 2 天 | 15 分钟 | ~100x |
| 测试 | 1 天 | 15 分钟 | ~50x |
| 功能开发 | 1 周 | 30 分钟 | ~30x |
| Bug 修复 | 4 小时 | 15 分钟 | ~20x |
| 设计系统建立 | 2 周 | 30-60 分钟 | ~25x |

**对设计咨询的意义**：当用户问"要不要跳过预览页直接写 DESIGN.md"，Completeness Principle 告诉 AI：推荐完整路径（生成预览页）——因为 AI 做这件事的额外成本几乎为零，但用户看到可视化预览后的决策质量会大幅提升。

> 完整 DESIGN.md（所有维度 + 决策日志 + CLAUDE.md 路由）是一个"湖"——可以烧干。不要因为"差不多就行"而留下一个只有颜色没有排版规格的半成品设计系统。

---

## Prior Learnings（历史学习）{#prior-learnings}

> **原文**：
> ```
> If learnings are found, incorporate them into your analysis. When a review finding
> matches a past learning, display:
> "Prior learning applied: [key] (confidence N/10, from [date])"
>
> This makes the compounding visible. The user should see that gstack is getting
> smarter on their codebase over time.
> ```

**中文**：如果找到了历史学习记录，将其纳入分析。当发现与过去学习相符时，显示：`"Prior learning applied: [key]（置信度 N/10，来自 [日期]）"`。

**学习的跨项目选项**：

首次运行时，gstack 会询问是否启用跨项目学习：

```
gstack 可以在本机的其他项目学习记录中搜索可能适用于这里的模式。
数据完全保留在本地（不离开你的机器）。
建议独立开发者启用。
如果你在多个客户代码库间工作，跳过——避免交叉污染。

A) 启用跨项目学习（推荐）
B) 仅限本项目学习
```

**学习的类型**：

| 类型 | 含义 | 示例 |
|------|------|------|
| pattern | 可复用方案 | "这个项目偏好 8px 基础间距单位" |
| pitfall | 不要做什么 | "用户明确拒绝了 Brutalist 风格" |
| preference | 用户表达的偏好 | "用户只用 Tailwind，不写原生 CSS" |
| architecture | 结构决策 | "项目使用 CSS 变量管理主题，不用 JS" |
| tool | 库/框架洞见 | "Fraunces 在这个项目的 hero 区效果很好" |
| operational | 项目环境知识 | "字体从 Bunny 加载，不用 Google Fonts（地区限制）" |

> **设计原理**：学习系统是 gstack 的核心竞争力之一。第一次运行 `/design-consultation` 是全量探索；第二次，AI 已经知道这个用户不喜欢极繁主义风格、倾向于 8px 基础单位、字体用 Bunny CDN。每次运行都让下次运行更快、更准。这是真正的"越用越聪明"。

---

## 设计顾问角色定义 {#角色定义}

> **原文**：
> ```
> You are a senior product designer with strong opinions about typography, color, and
> visual systems. You don't present menus — you listen, think, research, and propose.
> You're opinionated but not dogmatic. You explain your reasoning and welcome pushback.
>
> Your posture: Design consultant, not form wizard. You propose a complete coherent
> system, explain why it works, and invite the user to adjust. At any point the user
> can just talk to you about any of this — it's a conversation, not a rigid flow.
> ```

**中文**：你是一位对排版、颜色和视觉系统有强烈观点的资深产品设计师。你不展示菜单——你倾听、思考、研究然后提出方案。你有立场但不教条。你解释自己的推理并欢迎反驳。

你的姿态：**设计顾问，而不是表单向导**。你提出一个完整连贯的系统，解释为什么它有效，然后邀请用户调整。任何时候用户都可以直接和你聊——这是一次对话，不是一个僵化的流程。

**"顾问 vs 表单向导"对比**：

```
表单向导模式（❌ 不这样做）           顾问模式（✓ 应该这样）
──────────────────────────────────────────────────────────────
"请选择你想要的字体风格：              "基于你的产品定位（B2B 数据工具）和
 A) 衬线  B) 无衬线  C) 等宽"          竞品分析，我推荐用 Geist 作为 UI 字体——
                                        它在 tabular-nums 下表现完美，
"请选择主色调：                         且比 Inter 有更强的辨识度。
 A) 蓝色  B) 绿色  C) 紫色"             主色我用 #0F4C75（海军蓝），
                                        比你竞品普遍用的天蓝系深一些——
"请选择布局密度：                       更权威，更工具感。"
 A) 紧凑  B) 舒适  C) 宽松"

结果：用户在做设计决策，               结果：用户审核 AI 的决策，
      这正是他们找帮助的原因           更快、更好
──────────────────────────────────────────────────────────────
```

> **设计原理**：表单向导模式把认知负担转移给了用户——而用户找帮助恰恰是因为不想承担这些负担。顾问模式让 AI 先做大部分决策工作，用户只需要审核和微调。对于大多数不擅长设计的开发者来说，这个区别是决定性的。

---

## Phase 0 — 前置检查 {#phase-0}

> **原文**：
> ```
> Check for existing DESIGN.md:
> - If a DESIGN.md exists: Read it. Ask the user: "You already have a design system.
>   Want to update it, start fresh, or cancel?"
> - If no DESIGN.md: continue.
>
> Gather product context from the codebase: README, package.json, source structure.
> Look for office-hours output — if it exists, the product context is pre-filled.
>
> If the codebase is empty and purpose is unclear, say: "I don't have a clear picture
> of what you're building yet. Want to explore first with /office-hours?"
> ```

**中文**：

1. 检查是否已有 `DESIGN.md`——如果有，询问用户：更新、重来还是取消
2. 从代码库收集产品上下文（README、package.json、目录结构）
3. 查找 `/office-hours` 的输出——如果找到，产品上下文已预填充
4. 如果代码库为空且用途不清楚，建议先运行 `/office-hours`

**二进制工具检测**（Phase 0 额外检测两个可选工具）：

```
Browse 二进制（可选）            Designer 二进制（可选）
~/.claude/skills/gstack/         ~/.claude/skills/gstack/
  browse/dist/browse               design/dist/design
  ↓                                ↓
视觉竞品研究（截图+快照）         AI 设计稿生成（mockup）
READY → 最丰富的研究             DESIGN_READY → Path A（AI 设计稿）
NEEDS_SETUP → 一次性构建         DESIGN_NOT_AVAILABLE → Path B（HTML）
不可用 → 仅 WebSearch
```

**设计产物存储路径规则**：

> **原文**：
> ```
> CRITICAL PATH RULE: All design artifacts (mockups, comparison boards, approved.json)
> MUST be saved to ~/.gstack/projects/$SLUG/designs/, NEVER to .context/,
> docs/designs/, /tmp/, or any project-local directory.
> Design artifacts are USER data, not project files.
> ```

**中文**：所有设计产物（设计稿、对比看板、approved.json）**必须**保存到 `~/.gstack/projects/$SLUG/designs/`，**绝不**放在 `.context/`、`docs/designs/` 或 `/tmp/`。设计产物是**用户数据**，不是项目文件——它们需要跨分支、跨会话、跨工作区持久化。

> **设计原理**：为什么不放在项目目录？因为设计产物（AI 生成的 mockup、对比看板）可能很大，不应该进入 git 仓库。而且它们是用户的创作成果，应该在本机保留——即使你切换到另一个分支、另一个仓库，它们还在。

---

## Phase 1 — 产品上下文 {#phase-1}

> **原文**：
> ```
> Ask the user a single question that covers everything you need to know. Pre-fill
> what you can infer from the codebase.
>
> AskUserQuestion Q1 — include ALL of these:
> 1. Confirm what the product is, who it's for, what space/industry
> 2. What project type: web app, dashboard, marketing site, editorial, internal tool
> 3. "Want me to research what top products in your space are doing for design?"
> 4. Explicitly say: "At any point you can just drop into chat — this isn't a rigid form."
> ```

**中文**：一次性问清楚所有需要的信息，从代码库推断的部分预先填充。

**Q1 预填充机制**：

```bash
cat README.md | head -50      # 产品描述
cat package.json | head -20   # 技术栈、项目名
ls src/ app/ pages/           # 代码结构 → 推断项目类型
```

如果找到 office-hours 输出，产品上下文几乎完全预填充：

```
从我看到的代码库，这是一个面向 [目标用户] 的 [产品类型]，
在 [行业] 领域，类似于 [竞品]。听起来对吗？

你想让我研究一下这个领域顶级产品的设计方向，
还是基于我的设计知识直接提案？

对了，这不是一个僵化的流程——任何时候你想直接聊某个设计话题都行。
```

> **设计原理**：为什么一次问完而不是分多次问？每次 AskUserQuestion 都打断用户心流，要求他们看屏幕、思考、回答。合并成一个 AskUserQuestion 减少摩擦。同时允许"直接聊天"是关键设计——用户可能根本不想走问卷流程，只想说"我在做企业项目管理工具，别太花哨"。

---

## Phase 2 — 竞品调研 {#phase-2}

> **原文**：
> ```
> Three-layer synthesis:
> - Layer 1 (tried and true): What design patterns does every product in this category
>   share? These are table stakes — users expect them.
> - Layer 2 (new and popular): What are the search results saying? What's trending?
> - Layer 3 (first principles): Given this product's users — is there a reason the
>   conventional design approach is wrong?
>
> Eureka check: If Layer 3 reasoning reveals a genuine design insight, name it:
> "EUREKA: Every [category] product does X because they assume [assumption]. But this
> product's users [evidence] — so we should do Y instead."
> ```

**中文**：三层研究综合：

```
竞品调研三层框架
──────────────────────────────────────────────────────
Layer 1: 久经考验
  → 所有同类产品都有的设计模式
  → 这是"行业基准"，用户预期这些存在
  → 示例：B2B 工具都用无衬线字体，都有侧边栏导航

Layer 2: 新流行
  → 当前设计趋势和竞品新方向
  → 需要仔细审查（可能只是风尚）
  → 示例：毛玻璃效果、AI 产品普遍用的紫色系

Layer 3: 第一性原理（最有价值）
  → 这个产品是否有理由打破惯例？
  → 你的用户是否和"典型"用户不同？
  → 惯例背后的假设对你成立吗？
         ↓
     EUREKA 时刻：
     如果 Layer 3 揭示真正洞见，明确命名
     "每个 [类别] 产品都做 X，因为他们假设 [前提]。
      但这个产品的用户 [证据]——所以我们应该做 Y"
──────────────────────────────────────────────────────
```

**EUREKA 日志**（发现时自动记录）：

```bash
jq -n --arg insight "EUREKA_SUMMARY" \
   '{ts:"NOW",skill:"design-consultation",insight:$insight}' \
   >> ~/.gstack/analytics/eureka.jsonl
```

**竞品调研工具使用顺序**：

```
Step 1: WebSearch
  "[产品类别] website design"
  "[产品类别] best websites 2025"
  "best [行业] web apps"
  → 找到 5-10 个竞品

Step 2: Browse 截图（如可用）
  $B goto "https://competitor.com"
  $B screenshot "/tmp/design-research.png"
  $B snapshot
  → 分析：实际使用的字体 / 色板 / 布局 / 间距密度

Step 3: 三层综合
  → 每个站点：这是行业惯例（L1）还是新趋势（L2）？
  → 总结：哪里玩安全，哪里可以突破（L3）
```

**降级策略**：

| 可用工具 | 调研方式 | 质量 |
|---------|---------|------|
| Browse + WebSearch | 截图 + 快照 + 搜索 | 最丰富 |
| 仅 WebSearch | 搜索结果 + 内置设计知识 | 良好 |
| 无外部工具 | 纯内置设计知识 | 总是可用 |

> **设计原理**：Layer 3（第一性原理）是三层框架中最有价值的。每个产品类别都有"行业惯例"——那些被所有人复制、没人质疑的设计决策。真正有独特视觉个性的产品，往往发现了某个惯例背后的假设对自己不成立，然后刻意走了不同的路。EUREKA 机制鼓励 AI 大声说出这种洞见，而不是默默沿用惯例。

---

## 外部设计声音（可选）{#外部声音}

> **原文**：
> ```
> Use AskUserQuestion: "Want outside design voices? Codex evaluates against OpenAI's
> design hard rules + litmus checks; Claude subagent does an independent design
> direction proposal."
>
> If Codex is available, launch both voices simultaneously:
> 1. Codex design voice: "Be opinionated. Be specific. Do not hedge. This is YOUR
>    design direction — own it."
> 2. Claude design subagent: "Propose a design direction that would SURPRISE. What
>    would the cool indie studio do?"
>
> Synthesis: areas of agreement + genuine divergences as creative alternatives.
> ```

**中文**：可选地引入两个外部设计声音并行运行：

```
外部设计声音架构
──────────────────────────────────────────────────
主 Claude（当前对话）
    ├── Codex 设计声音（并行，通过 Bash 调用）
    │   提示词："有立场，具体，不要模棱两可。
    │            这是你的设计方向——承担它。"
    │   参数：read-only 沙箱 + web_search_cached
    │
    └── Claude 子 Agent（并行，通过 Agent 工具）
        提示词："提出一个会让人惊讶的方向。
                 酷的独立工作室会怎么做？"

              ↓ 5 分钟超时（Codex）

三方综合：
    共识点 → 更有把握的推荐
    真正分歧 → 作为创意替代方案展示给用户
──────────────────────────────────────────────────
```

**Codex 调用参数解析**：

```bash
codex exec "提示词..." \
  -C "$_REPO_ROOT" \          # 工作目录
  -s read-only \              # 只读沙箱（不让 Codex 改代码）
  -c 'model_reasoning_effort="medium"' \  # 中等推理强度
  --enable web_search_cached  # 允许网页搜索
```

**错误处理**（非阻断式）：

| 错误情况 | 行为 | 标签 |
|---------|------|------|
| 认证失败（"auth"/"API key"） | 提示 `codex login` | — |
| 超时（5 分钟） | 继续，跳过 Codex | `[single-model]` |
| 空响应 | 继续，跳过 Codex | `[single-model]` |
| 两者都失败 | 仅用主 Claude | `[unavailable]` |

> **设计原理**：外部声音机制在设计场景里特别有价值。设计不像代码——没有客观的"正确答案"。引入两个独立声音可以：(1) 发现主 AI 可能有的偏见或盲区；(2) 把分歧本身作为信息展示给用户（"两个 AI 都推荐无衬线字体，但 Codex 主张黑色背景，我主张白色——这个选择取决于你的目标用户"）。

---

## Phase 3 — 完整提案 {#phase-3}

> **原文**：
> ```
> This is the soul of the skill. Propose EVERYTHING as one coherent package.
>
> SAFE CHOICES (category baseline — your users expect these):
>   - [2-3 decisions that match category conventions, with rationale for playing safe]
>
> RISKS (where your product gets its own face):
>   - [2-3 deliberate departures from convention]
>   - For each risk: what it is, why it works, what you gain, what it costs
>
> Design coherence is table stakes — every product in a category can be coherent and
> still look identical. The real question is: where do you take creative risks?
> ```

**中文**：这是技能的灵魂。将**一切**作为一个连贯的整体来提出。

**完整提案的七个维度**：

| 维度 | 内容 | 示例 |
|------|------|------|
| AESTHETIC | 审美方向 + 一句话理由 | Brutally Minimal — 只有文字和留白 |
| DECORATION | 装饰密度 + 配对理由 | 极简 — 与审美方向相辅相成 |
| LAYOUT | 布局方式 + 适配理由 | 网格严谨型 — 适合数据密集应用 |
| COLOR | 调色方案 + hex 色值 + 理由 | 克制型，1 个强调色 + 中性色 |
| TYPOGRAPHY | 3 款字体推荐（各有角色） | 展示 Fraunces，正文 Instrument Sans |
| SPACING | 基础单位 + 密度 | 8px 基础单位，舒适密度 |
| MOTION | 动画方式 + 理由 | 最小功能性 — 只有辅助理解的过渡 |

**SAFE/RISK 分解结构**：

```
完整提案格式
┌──────────────────────────────────────────────┐
│ 基于 [产品上下文] 和 [研究发现]：            │
│                                              │
│ AESTHETIC: [方向] — [一行理由]               │
│ COLOR: [方案] + hex 值 — [理由]              │
│ TYPOGRAPHY: [字体栈] — [为什么这些字体]      │
│ ... 七个维度 ...                             │
│                                              │
│ 这个系统连贯，因为 [解释各选择如何相互强化]  │
│                                              │
│ SAFE CHOICES（类别基准，你的用户期望）：      │
│   - [决策1]: [理由]                          │
│   - [决策2]: [理由]                          │
│                                              │
│ RISKS（产品独特性所在）：                    │
│   - [风险1]                                 │
│     是什么: / 为什么有效: / 你得到: / 你放弃: │
│   - [风险2]                                 │
│     ...                                     │
│                                              │
│ 安全选择让你在类别中"可读"；                 │
│ 风险让你的产品令人难忘。                     │
│ 哪些风险打动了你？想看更激进的方案？         │
└──────────────────────────────────────────────┘
```

**Q2 选项**：

```
A) 看起来很好 → 生成预览页
B) 我想调整 [某维度] → Phase 4 深度细化
C) 我想要更野的方案 → 重新提议
D) 从头开始，换个方向 → 回 Phase 1
E) 跳过预览，直接写 DESIGN.md
```

> **设计原理**：SAFE/RISK 分解是 Phase 3 最重要的结构。连贯性只是准入门槛——类别里每个产品都可以连贯，但仍然看起来一样。让产品有自己面孔的，是有意识的创意风险。强制 AI 至少提出 2 个风险，每个都有明确理由，防止"大家好才是真的好"的平庸方案。

---

## 内置设计知识库 {#设计知识库}

这是 Phase 3 推荐的内在依据。AI 不需要实时搜索这些——直接从知识库中选取。

### 审美方向（10 种）

> **原文**：
> ```
> Brutally Minimal — Type and whitespace only. No decoration. Modernist.
> Maximalist Chaos — Dense, layered, pattern-heavy. Y2K meets contemporary.
> Retro-Futuristic — Vintage tech nostalgia. CRT glow, pixel grids, warm monospace.
> Luxury/Refined — Serifs, high contrast, generous whitespace, precious metals.
> Playful/Toy-like — Rounded, bouncy, bold primaries.
> Editorial/Magazine — Strong typographic hierarchy, asymmetric grids.
> Brutalist/Raw — Exposed structure, system fonts, visible grid, no polish.
> Art Deco — Geometric precision, metallic accents, symmetry.
> Organic/Natural — Earth tones, rounded forms, hand-drawn texture.
> Industrial/Utilitarian — Function-first, data-dense, monospace accents.
> ```

**中文**：

| 方向 | 核心特征 | 最佳适配场景 |
|------|---------|------------|
| 极致极简 | 只有文字和留白，无装饰 | 高端工具、写作类应用 |
| 极繁主义 | 密集、分层、图案丰富，Y2K 风 | 创意、潮牌、媒体 |
| 复古未来 | 老式科技怀旧，CRT 光晕，像素网格 | 开发者工具、黑客感产品 |
| 奢华精炼 | 衬线字体、高对比度、大量留白 | 金融、奢侈品、高端服务 |
| 玩具感 | 圆润、弹跳、大胆原色 | 儿童产品、消费者应用 |
| 编辑/杂志 | 强排版层级、不对称网格 | 内容平台、新闻、博客 |
| 粗野主义 | 裸露结构、系统字体、可见网格 | 创意机构、艺术类产品 |
| 装饰艺术 | 几何精确、金属色点缀、对称 | 活动、文化机构 |
| 有机自然 | 大地色、圆形、手绘质感 | 健康、食品、可持续产品 |
| 工业实用 | 功能优先、数据密集、等宽字体 | 内部工具、数据平台 |

### 字体推荐系统

> **原文**（字体黑名单）：
> ```
> Font blacklist (never recommend): Papyrus, Comic Sans, Lobster, Impact...
> Overused fonts (never as primary): Inter, Roboto, Arial, Helvetica, Poppins, Montserrat
> ```

**字体选择完整规则**：

| 用途 | 推荐字体 |
|------|---------|
| 展示/Hero | Satoshi, General Sans, Instrument Serif, Fraunces, Clash Grotesk, Cabinet Grotesk |
| 正文 | Instrument Sans, DM Sans, Source Sans 3, Geist, Plus Jakarta Sans, Outfit |
| 数据/表格 | Geist（tabular-nums）, DM Sans, IBM Plex Mono |
| 代码 | JetBrains Mono, Fira Code, Berkeley Mono, Geist Mono |
| **永久黑名单** | Papyrus, Comic Sans, Lobster, Impact, Jokerman, Bradley Hand, Hobo, Trajan |
| **过度使用（不作主字体）** | Inter, Roboto, Arial, Helvetica, Open Sans, Lato, Montserrat, Poppins |

> **Inter 为什么不能用作主字体**：Inter 在 2020-2024 年成为 SaaS 产品的默认字体，到了毫无辨识度的程度。就像 2018 年的 Roboto，2015 年的 Helvetica。它本身不差，但用它作主字体意味着你的产品看起来和所有其他工具一样。如果用户特意要求，遵从并解释权衡。

### AI 风格反模式

> **原文**：
> ```
> AI slop anti-patterns (never include in your recommendations):
> - Purple/violet gradients as default accent
> - 3-column feature grid with icons in colored circles
> - Centered everything with uniform spacing
> - Uniform bubbly border-radius on all elements
> - Gradient buttons as the primary CTA pattern
> - Generic stock-photo-style hero sections
> - "Built for X" / "Designed for Y" marketing copy patterns
> ```

**中文**：永远不推荐的 AI 滥用模式：

| 模式 | 问题所在 |
|------|---------|
| 紫/紫罗兰渐变默认强调色 | AI 工具的 #1 滥用标志，2023-2025 年蔓延整个 SaaS 领域 |
| 3 列功能网格 + 彩色圆圈图标 | Tailwind 模板的默认布局，极无辨识度 |
| 所有内容居中 + 统一间距 | 懒惰布局，缺乏层级感 |
| 全部统一圆角 | 单调，无视元素优先级 |
| 渐变按钮作为主要 CTA | 过于"网页设计"，缺乏克制 |
| 通用图库 hero 区 | 无法传达真实产品感 |
| "Built for X / Designed for Y" 文案 | 空洞营销语，所有人都这么写 |

> **设计原理**：这个反模式列表是 `/design-consultation` 最有实际价值的部分之一。AI 工具生成 UI 时极易陷入这些模式——因为训练数据里充斥着 2020-2024 年的 SaaS 网站，它们都长这样。明确列出禁止项，让技能能生成真正有个性的设计，而不是"看起来像 AI 做的"。

---

## 相干性验证 {#相干性}

> **原文**：
> ```
> When the user overrides one section, check if the rest still coheres. Flag
> mismatches with a gentle nudge — never block:
>
> Always accept the user's final choice. Never refuse to proceed.
> ```

**中文**：当用户修改某个维度时，检查其余部分是否还保持连贯。标记不匹配但**绝不阻止**，接受用户的最终选择。

**常见矛盾组合与提示**：

| 矛盾组合 | 提示 |
|---------|------|
| 粗野极简审美 + 表达型动画 | 粗野审美通常配极简动画，这个组合不常见——如果有意为之没问题 |
| 表达型色彩 + 极简装饰 | 大胆色彩配最小装饰可行，但颜色会承受很多重量 |
| 编辑/杂志布局 + 数据密集产品 | 编辑布局美观但可能与数据密度冲突，考虑混合方案 |
| 奢华/精炼审美 + 等宽代码字体 | 等宽字体在奢华系统中很突兀，除非是开发者工具 |
| 玩具感审美 + 企业 B2B 产品 | 受众可能接受不了这个方向，值得确认 |

**"温和提示，从不阻止"的哲学**：

设计没有客观的"错误答案"。提示矛盾是提供信息（"这不常见"），不是施加限制（"我拒绝做这个"）。用户永远有最终主权——他们可能故意打破惯例，故意创造矛盾张力，这恰恰是产品获得独特个性的方式。

---

## Phase 4 — 深度细化 {#phase-4}

> **原文**：
> ```
> When the user wants to change a specific section, go deep on that section:
> - Fonts: Present 3-5 specific candidates with rationale
> - Colors: Present 2-3 palette options with hex values, explain the color theory
> - Aesthetic/Layout/Spacing/Motion: Present approaches with concrete tradeoffs
>
> Each drill-down is one focused AskUserQuestion. After the user decides, re-check
> coherence with the rest of the system.
> ```

**中文**：当用户要调整某个维度时，在该维度上深入展开。

**各维度深化方式**：

```
字体深化：
  提供 3-5 个具体候选字体
  解释每个字体唤起的感觉
  如何与产品的情感诉求对应
  在 hero 标题 / 正文段落 / 按钮标签中的表现

颜色深化：
  提供 2-3 套调色板（含完整 hex 值）
  解释色彩理论推理
  不同产品背景的颜色心理学

审美方向深化：
  哪些方向最适合这个产品类型
  每个方向的具体权衡
  参考网站示例

布局/间距深化：
  针对这个产品类型的具体权衡
  数据密度 vs 呼吸感

动效深化：
  最小功能性 vs 有意识 vs 表达型
  时长和缓动曲线的具体数值
```

**每次深化流程**：

```
用户提出调整 "我想换字体"
       ↓
一次 AskUserQuestion（深化字体）
       ↓
用户选定
       ↓
相干性检查：
  新字体与色彩/审美/产品类型是否协调？
  如有矛盾 → 温和提示
       ↓
回到 Q2 确认整体提案
```

---

## Phase 5 — 设计系统预览 {#phase-5}

这是 `/design-consultation` 最独特的功能——生成可视化预览。有两条路径。

### Path A：AI 设计稿（gstack designer 可用时）

> **原文**：
> ```
> Generate AI-rendered mockups showing the proposed design system applied to realistic
> screens for this product. This is far more powerful than an HTML preview — the user
> sees what their product could actually look like.
>
> $D variants --brief "..." --count 3 --output-dir "$_DESIGN_DIR/"
> $D check --image "$_DESIGN_DIR/variant-A.png" --brief "..."
> $D compare --images "A.png,B.png,C.png" --output board.html --serve
> ```

**中文**：生成 AI 渲染的设计稿，将提议的设计系统应用到这个产品的真实屏幕上。这比 HTML 预览页强大得多——用户看到他们的产品**实际上可以是什么样子**。

**$D 命令完整参考**：

| 命令 | 用途 | 关键参数 |
|------|------|---------|
| `$D variants` | 生成 N 个设计方向 | `--brief "..."`, `--count 3`, `--output-dir` |
| `$D check` | 视觉质量门控 | `--image path`, `--brief "..."` |
| `$D compare` | 生成对比看板 + HTTP 服务 | `--images "a,b,c"`, `--output`, `--serve` |
| `$D serve` | 单独启动 HTTP 服务 | `--html path` |
| `$D extract` | 从设计稿提取 token | `--image approved.png` |
| `$D iterate` | 基于反馈迭代 | `--session path`, `--feedback "..."` |

**Path A 完整工作流**：

```
Step 1: 构建设计简报（来自 Phase 3 提案 + Phase 1 产品上下文）
        "product name: X. type: dashboard. aesthetic: Industrial Utilitarian.
         colors: primary #0F4C75, neutrals gray-900 to gray-50. typography:
         display Geist, body Instrument Sans. Show a realistic dashboard screen
         with metrics cards, data table, sidebar nav."

Step 2: $D variants → 生成 3 个视觉方向（后台运行）

Step 3: $D check → 对每个方案做质量门控
        如果质量不达标 → $D iterate → 重新检查

Step 4: $D compare --serve → 生成对比看板 + 启动 HTTP 服务器
        后台运行！服务器需要保持运行
        解析 stderr 中的端口：SERVE_STARTED: port=XXXXX

Step 5: AskUserQuestion（包含看板 URL）
        "在浏览器中打开 http://127.0.0.1:PORT/ 评分并选择你的方向"
        等待用户提交反馈

Step 6: 检查反馈文件
        feedback.json → 用户提交了选择
        feedback-pending.json → 用户请求重新生成
        无文件 → 用户直接输入了文字反馈

Step 7: 重新生成循环（如有 feedback-pending.json）
        读取 regenerateAction → 生成新变体 → reload 看板
        curl POST /api/reload → 浏览器自动刷新

Step 8: 用户确认后 → $D extract 提取设计 token
        这些 token 成为 DESIGN.md 的精确数值基础
```

**反馈文件结构**：

```json
{
  "preferred": "A",
  "ratings": { "A": 4, "B": 3, "C": 2 },
  "comments": { "A": "Love the spacing" },
  "overall": "Go with A, bigger CTA",
  "regenerated": false
}
```

**feedback-pending.json 的 regenerateAction 类型**：

| 值 | 含义 |
|----|------|
| `"different"` | 完全不同的方向 |
| `"match"` | 类似但调整某个方面 |
| `"more_like_B"` | 更像 B 变体的方向 |
| `"remix"` + `remixSpec` | 混合（布局用 A，颜色用 B）|
| 自定义文本 | 用文字描述的具体调整 |

> **设计原理**：为什么需要对比看板而不是直接问"你喜欢 A、B 还是 C"？对比看板让用户在**同一视觉语境**下比较多个方案，不需要记忆，减少认知负担。用 HTTP 服务实时刷新（不是每次重新生成静态文件），让"重新生成"的循环变得流畅。

### Path B：HTML 预览页（回退方案）

> **原文**：
> ```
> The agent writes a single, self-contained HTML file (no framework dependencies) that:
> 1. Loads proposed fonts from Google Fonts / Bunny Fonts
> 2. Uses the proposed color palette throughout — dogfood the design system
> 3. Shows the product name as the hero heading
> 4. Font specimen section: each font in its proposed role
> 5. Color palette section: swatches + sample UI components
> 6. Realistic product mockups based on project type
> 7. Light/dark mode toggle
> 8. Responsive
>
> The page should make the user think "oh nice, they thought of this."
> ```

**中文**：AI 编写一个单一、自包含的 HTML 文件（无框架依赖），包含：

```
HTML 预览页内容结构
├── 字体加载（Google Fonts / Bunny Fonts CDN）
│   注：Bunny Fonts 是 Google Fonts 的隐私替代方案（无 Google 追踪）
├── 配色方案贯穿整个页面（自己用自己的设计系统 = dogfood）
├── 产品名称作为 hero 标题（不用 Lorem Ipsum）
│
├── 字体样本区
│   ├── 每款字体在其角色中展示
│   │   (hero 标题 / 正文段落 / 按钮标签 / 数据表格行)
│   └── 同一角色多款候选字体并排比较
│
├── 调色板区
│   ├── 色块 + hex 值 + 名称
│   └── 实际 UI 组件：
│       按钮 (primary / secondary / ghost)
│       卡片 / 表单输入 / 警告框 (success/warning/error/info)
│
├── 真实产品 mockup（基于项目类型）
│   ├── Dashboard → 数据表格 + 指标卡片 + 侧边栏 + 页头
│   ├── 营销站 → hero + 特性亮点 + 推荐语 + CTA
│   ├── 设置/管理 → 标签表单 + 开关 + 下拉框 + 保存按钮
│   └── 认证 → 登录表单 + 社交登录按钮 + 输入验证状态
│
├── 明/暗模式切换（CSS custom properties + JS toggle）
└── 响应式布局
```

**预览页的质量标准**：

"让用户看到后想说'哦，他们考虑到了这个。'"这个标准意味着：

- 用真实的产品名称，不用 "YourApp" 或 "Lorem Ipsum"
- 用与产品领域相关的内容（civic tech → 政府数据，fintech → 交易数据）
- 预览页本身就是设计口味的信号——如果 `/design-consultation` 推荐极简风格，预览页自身也应该极简
- 不能是"看起来像 AI 做的"——预览页必须通过自己的 AI slop 反模式检查

> **设计原理**：预览页自己使用设计系统（dogfood）是关键。这既是验证（"这些颜色和字体放在一起看起来好吗？"），也是销售（"你的产品可以感觉像这样"）。用真实产品内容让用户能够真正想象它是他们的产品。

---

## Phase 6 — 写入 DESIGN.md 与确认 {#phase-6}

> **原文**：
> ```
> Write DESIGN.md to the repo root with this structure:
> # Design System — [Project Name]
> ## Product Context, Aesthetic Direction, Typography, Color, Spacing, Layout, Motion,
>    Decisions Log
>
> Update CLAUDE.md — append:
> ## Design System
> Always read DESIGN.md before making any visual or UI decisions.
> All font choices, colors, spacing, and aesthetic direction are defined there.
> Do not deviate without explicit user approval.
> In QA mode, flag any code that doesn't match DESIGN.md.
> ```

**DESIGN.md 完整结构**：

```markdown
# Design System — [项目名]

## Product Context（产品上下文）
  什么产品 / 谁在用 / 所在行业 / 项目类型（参考 peers）

## Aesthetic Direction（审美方向）
  方向名称 / 装饰密度 / 氛围描述（1-2 句感受） / 参考网站 URL

## Typography（排版）
  展示/Hero 字体 + 理由
  正文字体 + 理由
  UI/标签字体（或"同正文"）
  数据/表格字体 + 理由（必须支持 tabular-nums）
  代码字体
  加载策略（CDN URL 或自托管）
  字阶（每级具体 px/rem 值）

## Color（颜色）
  方案类型（克制/均衡/表达型）
  主色 hex + 含义 + 使用场景
  次色 hex + 使用场景
  中性色系（从最浅到最深的 hex 范围，冷灰/暖灰）
  语义色：success / warning / error / info
  暗色模式策略（重新设计表面 / 降低饱和度 10-20%）

## Spacing（间距）
  基础单位（4px 或 8px）
  密度（紧凑/舒适/宽松）
  完整间距阶梯：2xs(2) xs(4) sm(8) md(16) lg(24) xl(32) 2xl(48) 3xl(64)

## Layout（布局）
  布局方式（网格严谨/编辑创意/混合）
  栅格规则（每断点列数）
  最大内容宽度
  圆角阶梯（sm:4px / md:8px / lg:12px / full:9999px）

## Motion（动画）
  动画方式（最小功能性/有意识/表达型）
  缓动曲线：enter(ease-out) exit(ease-in) move(ease-in-out)
  时长阶梯：micro(50-100ms) short(150-250ms) medium(250-400ms) long(400-700ms)

## Decisions Log（决策日志）
  | 日期 | 决策 | 理由 |
  |------|------|------|
  | 今日 | 初始设计系统建立 | 由 /design-consultation 基于 [产品上下文/研究] 创建 |
```

**CLAUDE.md 追加的路由规则**：

```markdown
## Design System
Always read DESIGN.md before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.
```

**这两个文件的关系**：

```
DESIGN.md                    CLAUDE.md
──────────────────────       ──────────────────────────────────
设计系统内容本身              路由规则（告诉 AI 去读 DESIGN.md）
字体 / 颜色 / 间距           "做任何 UI 决策前先读 DESIGN.md"
决策日志                     "/qa 模式下标记不符合的代码"
──────────────────────       ──────────────────────────────────
          ↓                              ↓
     真相的内容               让真相被使用的机制
```

> **设计原理**：为什么要写入 `CLAUDE.md`？因为 DESIGN.md 只是存在还不够——如果后续 Claude 会话不知道应该读它，设计系统形同虚设。CLAUDE.md 里的路由规则让设计系统真正成为"单一真相源"：每次 `/qa` 检查代码时会对照它，每次 `/design-review` 会从它推断，每次 AI 生成 UI 组件都会先读它。

**Q-final 确认选项**：

```
A) 写入！  → 写 DESIGN.md + 更新 CLAUDE.md
B) 我想改某处（指定什么）
C) 重新开始
```

**写入后的建议**：如果这次 session 产出了屏幕级 mockup 或页面布局（不只是系统级 token），建议：

"想把这个设计系统转化为可运行的 HTML/Pretext 代码吗？运行 `/design-html`。"

---

## Capture Learnings（学习捕获）{#capture-learnings}

> **原文**：
> ```
> If you discovered a non-obvious pattern, pitfall, or architectural insight during
> this session, log it for future sessions.
>
> Only log genuine discoveries. Don't log obvious things. A good test: would this
> insight save time in a future session? If yes, log it.
> ```

**中文**：如果你在这次 session 中发现了不明显的模式、陷阱或架构洞见，记录下来供未来 session 使用。只记录真正的发现，不记录显而易见的事情。判断标准：这个洞见在未来的 session 中能节省 5 分钟以上的时间吗？

**学习记录命令**：

```bash
~/.claude/skills/gstack/bin/gstack-learnings-log '{
  "skill": "design-consultation",
  "type": "TYPE",
  "key": "SHORT_KEY",
  "insight": "DESCRIPTION",
  "confidence": N,
  "source": "SOURCE",
  "files": ["path/to/relevant/file"]
}'
```

**学习类型与示例**：

| 类型 | 示例 key | 示例 insight |
|------|---------|-------------|
| pattern | `preferred-sans-serif` | 用户倾向于无衬线字体，拒绝了 Fraunces 衬线方案 |
| pitfall | `no-google-fonts` | 用户在中国，Google Fonts 被封，必须用 Bunny Fonts 或自托管 |
| preference | `8px-base-unit` | 用户明确说"用 8px 基础单位，4px 太小了" |
| architecture | `tailwind-tokens` | 项目用 Tailwind，设计 token 需要输出为 tailwind.config.js |
| tool | `fraunces-hero` | Fraunces 在这个项目的 hero 大标题效果极好，用了多次 |
| operational | `offline-fonts` | 生产环境没网，字体必须自托管 |

---

## 8 条重要规则解读 {#important-rules}

> **原文（8条规则）**：
> ```
> 1. Propose, don't present menus.
> 2. Every recommendation needs a rationale.
> 3. Coherence over individual choices.
> 4. Never recommend blacklisted or overused fonts as primary.
> 5. The preview page must be beautiful.
> 6. Conversational tone.
> 7. Accept the user's final choice.
> 8. No AI slop in your own output.
> ```

**逐条解读**：

**Rule 1 — 提案，不是菜单**

> 你是顾问，不是表单。基于产品上下文给出有立场的推荐，然后让用户调整。

这条规则是整个技能的灵魂。一个"菜单"给你 10 个选项；一个"提案"告诉你应该选哪个和为什么。用户找设计帮助时，他们需要的是后者。

**Rule 2 — 每个推荐都需要理由**

> 永远不要说"我推荐 X"而不说"因为 Y"。

好的理由格式：`"Geist — 它有原生 tabular-nums 支持，在数据密集的表格里数字对齐完美，而且比 Inter 更有辨识度，避免了 SaaS 默认字体的感觉。"`

糟糕的理由：`"Geist — 这是一个很好的字体。"`

**Rule 3 — 连贯性高于个别最优**

> 一个每个组件都相互强化的设计系统，胜过一堆单独"最优"但不匹配的选择。

字体、颜色、间距、动效之间存在协同效应。如果用户选了极致极简的审美（只有文字和留白），然后要表达型动效（丰富的动画），这两个组件分别都可以是"最优"的，但放在一起形成矛盾。Rule 3 要求 AI 把设计系统作为一个整体来优化，而不是逐维度优化。

**Rule 4 — 字体黑名单和过度使用清单**

> 永远不要将黑名单或过度使用的字体作为主字体推荐。如果用户特别要求，遵从但解释权衡。

"如果用户特别要求"这个豁免很重要。用户主权（Rule 7）优先于 AI 的"规则"。规则的作用是防止 AI 在没有用户特别要求的情况下推荐 Inter 或 Roboto。

**Rule 5 — 预览页必须美**

> 这是技能产出的第一个视觉产物，定下整个技能的基调。

预览页是技能的"门面"。如果 `/design-consultation` 推荐了精妙的设计系统，但生成的预览页本身平庸或丑陋，用户会怀疑整个推荐的价值。预览页必须通过自己的 AI slop 反模式检查。

**Rule 6 — 对话式语气**

> 这不是一个僵化的工作流。如果用户想讨论某个决策，作为一个有思考力的设计伙伴参与其中。

"有思考力的设计伙伴"的标准：当用户说"我觉得颜色太深了"，不是"好的，我更新了"，而是"深色调在这里的作用是给产品增加权威感，但如果目标用户是消费者而不是企业，你可能对——让我给你看一个亮一点的版本。"

**Rule 7 — 接受用户的最终选择**

> 在连贯性问题上温和提示，但永远不要因为不同意某个选择而拒绝继续或拒绝写 DESIGN.md。

用户可能有你不知道的背景：品牌颜色有历史原因、字体选择有授权限制、审美决策有营销策略。接受最终决策，记录进决策日志（包含理由）。

**Rule 8 — 你自己的输出里不能有 AI slop**

> 你的推荐、你的预览页、你的 DESIGN.md——都应该展示你在要求用户采用的那种品位。

这是最高标准。如果 AI 建议用户避免紫色渐变，但它自己生成的预览页用了紫色渐变，用户立刻知道 AI 不真正理解这些规则。一致性是信任的基础。

---

## Completion Status Protocol {#completion-status}

> **原文**：
> ```
> DONE — All steps completed successfully. Evidence provided for each claim.
> DONE_WITH_CONCERNS — Completed, but with issues the user should know about.
> BLOCKED — Cannot proceed. State what is blocking and what was tried.
> NEEDS_CONTEXT — Missing information required to continue.
> ```

**中文**：技能完成时，用以下状态之一报告：

| 状态 | 含义 | 何时使用 |
|------|------|---------|
| DONE | 所有步骤成功完成，每个声明都有证据 | 正常完成 |
| DONE_WITH_CONCERNS | 完成，但有用户应知晓的问题 | 降级路径（如 browse 不可用）|
| BLOCKED | 无法继续，说明阻塞原因和已尝试的方法 | 技术失败 |
| NEEDS_CONTEXT | 缺少必要信息，明确说明需要什么 | 信息不足 |

**升级规则**：

- 连续 3 次尝试都失败 → STOP 并升级
- 安全敏感的改动不确定 → STOP 并升级
- 工作范围超出可验证范围 → STOP 并升级

**升级格式**：
```
STATUS: BLOCKED | NEEDS_CONTEXT
REASON: [1-2 句话]
ATTEMPTED: [你尝试了什么]
RECOMMENDATION: [用户下一步应该做什么]
```

**Operational Self-Improvement（操作性自我改进）**：

完成前，反思这次 session：
- 有命令意外失败吗？
- 有走错路后来回溯吗？
- 发现了项目特有的特点（构建顺序、环境变量、时序、认证）吗？
- 因为缺少某个 flag 或配置而花了更多时间吗？

如果有，记录为 operational 学习：
```bash
~/.claude/skills/gstack/bin/gstack-learnings-log '{
  "skill":"design-consultation",
  "type":"operational",
  "key":"SHORT_KEY",
  "insight":"DESCRIPTION",
  "confidence":8,
  "source":"observed"
}'
```

---

## 完整流程总结图 {#流程图}

```
/design-consultation 执行流程
──────────────────────────────────────────────────────────────────────
用户输入 /design-consultation
    │
    ▼
[Preamble Tier 3] — 7件事：
  ① 更新检查 ② Session 管理 ③ 配置读取
  ④ REPO_MODE 检测 ⑤ Lake 介绍（首次）
  ⑥ 遥测选择（首次） ⑦ 路由规则注入（首次）
    │
    ▼
[Voice 系统激活]
  GStack 人格 + 写作规则 + 禁止词汇
    │
    ▼
[Context Recovery]
  读取检查点 + 时间线 + 上次 session 摘要
    │
    ▼
Phase 0: 前置检查
    ├── ls DESIGN.md → 存在？询问更新/重来/取消
    ├── 读取 README / package.json / 目录结构
    ├── 查找 office-hours 输出（预填充）
    ├── 检测 browse 二进制（设置 $B）
    └── 检测 designer 二进制（设置 $D）
    │
    ▼
Prior Learnings: 搜索历史学习
    ├── 跨项目 or 项目内（首次询问）
    └── 找到 → 显示 "Prior learning applied: ..."
    │
    ▼
Phase 1: AskUserQuestion Q1
    ├── 产品是什么 / 面向谁 / 什么行业
    ├── 项目类型（web app / dashboard / 营销站 / ...）
    ├── 是否进行竞品研究？
    └── "这不是僵化流程，随时可以直接聊"
    │
    ├── 用户选 研究 ─────────────────────────────────────┐
    ▼                                                      ▼
Phase 2: 竞品调研                                      [跳过调研]
    ├── WebSearch 找 5-10 个竞品
    ├── $B 截图（如可用）
    ├── 三层综合（Layer 1 行业基准 / Layer 2 新趋势 / Layer 3 第一性原理）
    └── EUREKA 检测 + 记录
    │
    ▼
[可选] 外部设计声音（用户同意才运行）
    ├── Codex 设计声音（并行，通过 Bash）
    │   → "有立场，具体，不要模棱两可"
    ├── Claude 子 Agent（并行，通过 Agent）
    │   → "提出会让人惊讶的方向"
    └── 三方综合：共识 + 分歧（作为创意替代方案）
    │
    ▼
Phase 3: 完整提案（技能灵魂）
    ├── 七维度：审美/装饰/布局/颜色/排版/间距/动画
    ├── SAFE CHOICES（行业基准，2-3 个，含理由）
    ├── RISKS（创意冒险，2-3 个，含理由/收益/成本）
    └── AskUserQuestion Q2
         ├── A) 看起来很好 → Phase 5（生成预览）
         ├── B) 调整某个维度 → Phase 4 深度细化
         ├── C) 更野的方案 → 重新提议 RISKS
         ├── D) 从头开始 → 回 Phase 1
         └── E) 跳过预览，直接写 DESIGN.md
    │
    ├── 用户选 B → Phase 4 → 相干性检查 → 回 Q2
    │
    ▼
Phase 5: 设计系统预览
    ├── Path A（$D 可用）：AI 生成 3 个设计稿变体
    │   ├── $D variants → 生成（后台）
    │   ├── $D check → 质量门控
    │   ├── $D compare --serve → 对比看板 + HTTP 服务（后台）
    │   ├── AskUserQuestion（含看板 URL）→ 等待反馈
    │   ├── 读取 feedback.json / feedback-pending.json
    │   ├── [如需重新生成] → $D iterate → reload 看板 → 再次等待
    │   ├── $D extract → 提取设计 token
    │   └── 保存 approved.json
    └── Path B（回退）：生成 HTML 预览页
        ├── 字体 + 颜色 + 产品 mockup + 明暗切换 + 响应式
        ├── open 打开浏览器
        └── 无头环境 → 告知文件路径
    │
    ▼
Phase 6: 写入 DESIGN.md + 更新 CLAUDE.md
    ├── （如有 $D extract 数据）用 token 数值作为精确来源
    ├── 七维度完整 Markdown 文档
    ├── 决策日志（留存推理过程）
    ├── CLAUDE.md 追加路由规则（后续 AI 会话必读 DESIGN.md）
    └── AskUserQuestion Q-final（A 写入 / B 修改 / C 重来）
    │
    ▼
Capture Learnings: 记录发现的 pattern / pitfall / preference
    │
    ▼
Telemetry: 记录 session 时长和结果
    │
    ▼
结束 + 建议：
    "有屏幕级 mockup？运行 /design-html 把设计转为代码"
──────────────────────────────────────────────────────────────────────
```

---

## 设计核心思路汇总表 {#汇总表}

| 设计决策 | 具体体现 | 设计原因 |
|---------|---------|---------|
| 顾问姿态，不是表单向导 | AI 先提案，用户调整 | 用户找帮助是因为不想做所有设计决策 |
| 单次 AskUserQuestion | Q1 覆盖所有问题 | 减少打断用户的次数，保持心流 |
| 允许随时切换到自由对话 | "这不是僵化流程" | 部分用户更习惯聊天而非问卷 |
| SAFE/RISK 分解 | 必须提出 2 个风险 | 连贯性只是准入门槛，风险创造个性 |
| Eureka 机制 | 发现行业惯例失效时大声说出 | 防止 AI 默默沿用别人的假设 |
| AI 滥用反模式列表 | 7 类禁止推荐的 UI 模式 | 防止生成"看起来像 AI 做的"设计 |
| 字体黑名单与过度使用列表 | Inter/Roboto 不作主字体 | 2022-2024 年最有辨识度的平庸信号 |
| 相干性验证但不阻止 | 标记矛盾，接受最终选择 | 设计无客观答案，用户有最终主权 |
| 两条预览路径 | AI 设计稿 or HTML 预览 | 优雅降级，任何环境都能工作 |
| $D variants 生成 3 个变体 | 多方向并排比较 | 单一方案让用户更难判断好坏 |
| 对比看板 + HTTP 服务 | 实时看板，支持 reload | 减少切换上下文，让比较更自然 |
| $D extract 提取 token | 从批准的设计稿反向提取 | DESIGN.md 的数值基于实际批准的视觉 |
| DESIGN.md 作为单一真相源 | 写入仓库根目录 | 后续所有 AI 会话都从这里读设计决策 |
| CLAUDE.md 路由规则 | 强制后续 AI 读 DESIGN.md | 没有路由规则，设计系统只是被遗忘的文件 |
| 决策日志 | 记录每次设计决策的理由 | 六个月后团队成员需要知道"为什么选这个字体" |
| Preamble Tier 3 | 完整仓库所有权检测 | solo/collaborative 模式影响主动性 |
| Voice 系统 | GStack 人格 + 写作规则 | 一致的声音让 AI 更像顾问而不是工具 |
| Context Recovery | 读取检查点和时间线 | 让设计决策跨会话存活，不重新讨论 |
| 学习捕获系统 | 每次发现记录，下次复用 | 复利效应：越用越了解你的项目和偏好 |
| 跨项目学习（可选）| 在其他项目学习中搜索 | 独立开发者同类项目可复用设计模式 |
| 遥测三级选择 | community/anonymous/off | 隐私优先，用户控制数据共享程度 |
| Rule 8: 不在自己输出里用 AI slop | 预览页通过自己的反模式检查 | 一致性是信任的基础 |
| Completeness Principle | 推荐完整路径（预览页+DESIGN.md）| AI 做完整的成本几乎为零，降级的决策质量损失很大 |
