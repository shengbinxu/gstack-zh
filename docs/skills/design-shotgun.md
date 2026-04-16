# `/design-shotgun` 技能逐段中英对照注解

> 对应源文件：[`design-shotgun/SKILL.md`](https://github.com/garrytan/gstack/blob/main/design-shotgun/SKILL.md)（954 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: design-shotgun
preamble-tier: 2
version: 1.0.0
description: |
  Design shotgun: generate multiple AI design variants, open a comparison board,
  collect structured feedback, and iterate. Standalone design exploration you can
  run anytime. Use when: "explore designs", "show me options", "design variants",
  "visual brainstorm", or "I don't like how this looks".
  Proactively suggest when the user describes a UI feature but hasn't seen
  what it could look like. (gstack)
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---
```

**中文翻译与解读**：

- **name: design-shotgun**：技能名称。"shotgun"是"散弹枪"——同时射出多个方向，看哪个命中目标。
- **preamble-tier: 2**：与 design-html 相同的 tier。包含环境初始化、会话追踪，但不做完整 repo 扫描。
- **核心描述**：生成多个 AI 设计变体，打开比较板，收集结构化反馈，迭代。可以**随时独立运行**，不需要先跑其他技能。
- **触发时机**："explore designs" / "show me options" / "design variants" / "visual brainstorm" / "I don't like how this looks"。最后一个特别重要——当用户对**现有设计**不满意时也可以用。
- **Proactive 触发**：用户描述了一个 UI 功能但还没见过它"长什么样"时，AI 会主动建议运行。
- **allowed-tools 没有 Edit 和 Write（对项目文件）**：design-shotgun 是**纯探索**，只生成图片和 HTML 比较板，不写项目代码。写操作只对 `~/.gstack/` 里的用户数据目录（`approved.json` 等）。

> **设计原理：为什么没有 Edit/Write？**
> 探索阶段不应该动代码。如果 AI 在你还没确认方向时就开始改代码，你会陷入"为什么它改了这里"的困惑里。探索和实现是两件事，对应两个技能：shotgun 探索，html 实现。

---

## "Shotgun" 命名解析

### 散弹枪比喻

```
传统 AI 设计方式（步枪）：       Shotgun 方式（散弹枪）：

    瞄准 ──→ 一个设计              ─────────────────────────
                                   ───────  方向 A  ─────────  →?
                                   ─── 方向 B ──────────────  →?
                                   ──────── 方向 C ─────────  →?
                                   ─── 方向 D ──────────────  →?
                                   ─────────────────────────
                                        同时发射，看哪个命中
```

**步枪模式的问题**：一个设计 → 用户说"不太对" → 再生成一个 → 再说"也不对" → 线性迭代，每次都要等 60 秒，效率极低。

**Shotgun 的价值**：多方向同时生成 → 用户一次看全 → 选方向 → 基于选定方向精化。把"哪个方向对"的问题变成了并行探索，而不是串行猜测。

### 心理学基础：比较选择 vs 凭空创造

用户很难描述"我想要什么样的设计"，但**很容易指出"哪个接近我想要的"**。

```
凭空描述（难）：                  比较选择（容易）：
"我想要... 嗯... 现代感            A 图：有点太深色了
 但又不太暗... 字体要清晰            B 图：这个空白感觉对
 但不要太正式... 颜色嘛..."          C 图：颜色不错但布局不好
                                    → 用 B 的布局 + C 的颜色
```

Shotgun 利用了人类"比较判断"比"生成描述"容易的认知特点。

---

## 在 gstack 设计流水线中的位置

```
用户有想法
    │
    ▼
/office-hours ──→ 产品定义文档
    │
    ▼
/plan-ceo-review ──→ CEO 方案
    │              （可选，有方案时 shotgun 会读取）
    ▼
[**你在这里**] /design-shotgun
    │
    ├─ DESIGN_READY: 生成 3-8 个 AI 设计变体
    ├─ 打开比较板
    ├─ 用户选择 + 反馈
    └─ 保存 approved.json
    │
    ▼
/design-html ──→ 把选定方向变成生产级 HTML
    │
    ▼
/ship ──→ 提交、推送、PR
```

**位置特点**：
1. Shotgun **可以独立运行**（不需要先跑 office-hours 或 plan-ceo-review）
2. 有上下文时 shotgun 会自动读取（CEO plan、DESIGN.md、之前的 approved.json）
3. Shotgun 的产物（approved.json + 选定 PNG）直接被 design-html 消费

---

## Preamble（前置环境）说明

Shotgun 使用 preamble-tier: 2，与 design-html 完全相同。核心变量：

| 变量 | 含义 | 影响什么 |
|------|------|---------|
| `$D` | 设计生成二进制路径 | 生成 mockup 的核心工具 |
| `$B` | 无头浏览器路径 | 截图当前页面，打开比较板 |
| `PROACTIVE` | 是否主动建议技能 | true = 主动建议；false = 等用户输入 |
| `SLUG` | 项目标识符 | 确定 `~/.gstack/projects/$SLUG/` 的路径 |
| `_BRANCH` | 当前 git 分支 | 记录在 approved.json 里 |

---

## DESIGN SETUP：工具检测

> **原文**（第 543-563 行）：
> ```bash
> _ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
> D=""
> [ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/design/dist/design" ] && D="..."
> [ -z "$D" ] && D=~/.claude/skills/gstack/design/dist/design
> if [ -x "$D" ]; then
>   echo "DESIGN_READY: $D"
> else
>   echo "DESIGN_NOT_AVAILABLE"
> fi
> ```
>
> If `DESIGN_NOT_AVAILABLE`: skip visual mockup generation and fall back to the
> existing HTML wireframe approach (`DESIGN_SKETCH`). Design mockups are a
> progressive enhancement, not a hard requirement.

**中文**：

```
检测优先级（高 → 低）：
1. 项目目录里的 design 二进制（vendored）
2. 用户主目录的 design 二进制（全局安装）

降级策略：
DESIGN_READY     → 使用 $D 生成 AI 图片 mockup
DESIGN_NOT_AVAIL → 跳过图片生成，改用 DESIGN_SKETCH
                   （ASCII art 或 HTML wireframe 方式展示设计概念）
```

**DESIGN_SKETCH 降级方案**：

```
如果 $D 不可用，AI 用 HTML wireframe 代替：

┌─────────────────────────────────────┐
│ VARIANT A: "极简黑白"               │
│                                     │
│  ┌───────────────────────────────┐  │
│  │    [Logo]    Nav  Nav  Nav    │  │
│  └───────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │   HERO HEADLINE             │   │
│  │   Subhead text here         │   │
│  │   [Get Started]             │   │
│  │                             │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

> **设计原理**：视觉 mockup 是增强，不是前提。核心工作流（提出方向 → 选择 → 精化）在没有 AI 图片生成的情况下也能运转。

---

## Step 0：会话检测

### 原文（第 586-616 行）

> ```bash
> eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
> setopt +o nomatch 2>/dev/null || true
> _PREV=$(find ~/.gstack/projects/$SLUG/designs/ -name "approved.json" -maxdepth 2 2>/dev/null | sort -r | head -5)
> [ -n "$_PREV" ] && echo "PREVIOUS_SESSIONS_FOUND" || echo "NO_PREVIOUS_SESSIONS"
> ```

**中文**：技能首先检测这个项目是否有**之前的设计探索会话**（approved.json 文件）。

```
PREVIOUS_SESSIONS_FOUND → 显示历史摘要，AskUserQuestion：
  "Previous design explorations for this project:
   - [date]: [screen] — chose variant [X], feedback: '[summary]'
   
   A) Revisit — 重新打开比较板，调整之前的选择
   B) New exploration — 全新探索，新的或更新的需求
   C) Something else"

NO_PREVIOUS_SESSIONS → 显示首次欢迎消息：
  "This is /design-shotgun — your visual brainstorming tool.
   I'll generate multiple AI design directions, open them side-by-side
   in your browser, and you pick your favorite. Let's start."
```

> **为什么要检查历史会话？**
> 设计探索是迭代的。用户可能两天前探索了 landing page 的方向，今天想继续调整。会话检测避免了重新开始的摩擦——发现历史，直接延续。

---

## Step 1：上下文收集

### 五维上下文

> **原文**（第 626-631 行）：
> ```
> Required context (5 dimensions):
> 1. Who — who is the design for? (persona, audience, expertise level)
> 2. Job to be done — what is the user trying to accomplish on this screen/page?
> 3. What exists — what's already in the codebase? (existing components, pages, patterns)
> 4. User flow — how do users arrive at this screen and where do they go next?
> 5. Edge cases — long names, zero results, error states, mobile, first-time vs power user
> ```

**中文**：

| 维度 | 问题 | 为什么重要 |
|------|------|---------|
| **Who** | 这是给谁用的？ | B2B vs B2C 的设计语言完全不同 |
| **JTBD** | 用户在这个页面要完成什么？ | 目标决定 CTA 的位置和权重 |
| **What exists** | 已有什么？ | 保持一致性，不重复设计已有元素 |
| **User flow** | 从哪来，到哪去？ | 决定信息架构和导航方式 |
| **Edge cases** | 长名字/零结果/错误/移动端？ | 避免"在 demo 上好看但在真实场景崩溃" |

### 自动收集上下文

> **原文**（第 633-660 行）：
> ```bash
> cat DESIGN.md 2>/dev/null | head -80 || echo "NO_DESIGN_MD"
> ls src/ app/ pages/ components/ 2>/dev/null | head -30
> ls ~/.gstack/projects/$SLUG/*office-hours* 2>/dev/null | head -5
>
> # 检测本地运行中的站点
> curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "NO_LOCAL_SITE"
> ```

**中文**：自动检测四个信息来源，减少用户需要主动提供的信息：

```
自动发现：
┌─────────────────────────────────────────────────────────┐
│ DESIGN.md       → 品牌颜色、字体、间距 token            │
│ src/app/pages/  → 已有页面和组件（知道"现有什么"）       │
│ office-hours 文档 → 产品目标和用户描述                  │
│ localhost:3000  → 是否有运行中的站点                    │
└─────────────────────────────────────────────────────────┘
```

**本地站点检测的特殊用途**：

如果本地站点在运行，且用户说了"I don't like how this looks"（我不喜欢现在的样子），AI 会：
1. 截图当前页面：`$B screenshot current.png`
2. 用 `$D evolve` 而不是 `$D variants` 生成改进版本
3. 这样生成的变体是基于**现有设计的改进**，而不是从零开始

### 精简的 AskUserQuestion

> **原文**（第 663-670 行）：
> ```
> AskUserQuestion with pre-filled context: Pre-fill what you inferred from the
> codebase, DESIGN.md, and office-hours output. Then ask for what's missing.
> Frame as ONE question covering all gaps:
>
> "Here's what I know: [pre-filled context]. I'm missing [gaps].
>  Tell me: [specific questions about the gaps].
>  How many variants? (default 3, up to 8 for important screens)"
> ```

**中文**：这个设计很精妙——AI 先展示"我已经知道了什么"，再只问"我缺少什么"，而不是把所有问题都抛给用户。

```
差的问法：
"请告诉我：
 1. 这是什么产品？
 2. 目标用户是谁？
 3. 有没有现有的设计系统？
 4. 你用什么技术栈？
 5. 需要几个变体？
 ..."
用户：（崩溃）

好的问法：
"我知道：这是 MyApp，一个企业 SaaS 工具，目标用户是 HR 经理，
 DESIGN.md 指定了蓝色主题，有 12 个现有组件（Button, Table, Modal...）。
 
 我缺少：这个 dashboard 屏幕的具体功能。用户需要看什么数据？
 需要几个变体？（默认 3 个）"
用户：（只需要回答一个具体问题）
```

> **"两轮上限"规则**：最多 2 轮上下文收集，然后就带着假设前进。不能让收集阶段无限拖延，这会消耗用户耐心。

---

## Step 2：口味记忆（Taste Memory）

### 原文（第 672-688 行）

> ```bash
> _TASTE=$(find ~/.gstack/projects/$SLUG/designs/ -name "approved.json" -maxdepth 2 2>/dev/null | sort -r | head -10)
> ```
>
> If prior sessions exist, read each `approved.json` and extract patterns from the
> approved variants. Include a taste summary in the design brief:
>
> "The user previously approved designs with these characteristics: [high contrast,
> generous whitespace, modern sans-serif typography, etc.]. Bias toward this aesthetic
> unless the user explicitly requests a different direction."

**中文**：读取最近 10 个 `approved.json`，从用户**之前选过的设计**中提取审美偏好。

这是一个**隐式学习机制**：

```
第一次运行 /design-shotgun：
  用户选了 A（深色、高对比度、无衬线字体）
  → 保存到 approved.json

第二次运行 /design-shotgun（不同屏幕）：
  AI 读取历史：
  "上次用户选了 高对比度 + 无衬线字体 → 偏向这个风格生成变体"
  → 新的 3 个变体都更接近用户的审美
  → 用户需要更少的迭代就能找到满意的
```

> **设计原理**：设计一致性是专业感的来源。如果每次 AI 都"猜测"用户的风格，你的产品会看起来是"多个设计师做的"。口味记忆让 AI 的生成结果越来越接近用户的真实偏好，同时保留用户覆盖的能力（"这次我想要完全不同的风格"）。

---

## Step 3：生成变体

### Step 3a：概念生成（文字先行）

> **原文**（第 703-718 行）：
> ```
> Before any API calls, generate N text concepts describing each variant's design direction.
> Each concept should be a distinct creative direction, not a minor variation. Present them
> as a lettered list:
>
> A) "Name" — one-line visual description of this direction
> B) "Name" — one-line visual description of this direction
> C) "Name" — one-line visual description of this direction
> ```

**中文**：在调用 API 生成图片**之前**，先用文字描述每个方向。这很关键：

```
为什么先做文字概念确认？

❌ 不确认直接生成：
   生成 3 张图（每张 60s = 3 分钟）
   ↓
   用户："我不要 dark mode，全是 dark mode..."
   ↓
   重新生成 3 张图（又 3 分钟）
   总计：6+ 分钟白费

✅ 先确认概念：
   文字描述概念（5 秒）
   ↓
   用户："把 B 改成浅色系"
   ↓
   确认后生成（3 分钟）
   总计：3 分钟，结果符合预期
```

**例子：**

```
I'll explore 3 directions for your pricing page:

A) "Corporate Clarity"
   — Light background, structured table layout, emphasis on plan comparison,
     conservative typography. Suits enterprise buyers who need to justify cost.

B) "Consumer Delight"
   — Vibrant accent colors, card-based plans, annual/monthly toggle,
     playful copy. Suits direct-to-consumer SaaS.

C) "Minimalist Premium"
   — Dark mode, generous whitespace, single recommended plan highlighted,
     premium feel. Suits design-forward products targeting designers.
```

### Step 3b：概念确认

> **原文**（第 720-735 行）：
> ```
> AskUserQuestion to confirm before spending API credits:
> "These are the {N} directions I'll generate. Each takes ~60s, but I'll run them
>  all in parallel so total time is ~60 seconds regardless of count."
>
> Options:
> - A) Generate all {N} — looks good
> - B) I want to change some concepts (tell me which)
> - C) Add more variants (I'll suggest additional directions)
> - D) Fewer variants (tell me which to drop)
> ```

**中文**：这里明确告诉用户**并行生成的时间特点**：不管 3 个还是 8 个，总时间都是约 60 秒，因为并行执行。这消除了"多要几个变体会更慢"的顾虑。

**最多 2 轮修改**：如果用户要求改概念，AI 最多调整 2 次，然后强制前进。防止在概念阶段无限打磨。

### Step 3c：并行生成（技术核心）

> **原文**（第 744-786 行）：
> ```
> Launch N Agent subagents in a single message (parallel execution). Use the Agent
> tool with subagent_type: "general-purpose" for each variant. Each agent is independent
> and handles its own generation, quality check, verification, and retry.
>
> Important: $D path propagation. The $D variable from DESIGN SETUP is a shell
> variable that agents do NOT inherit. Substitute the resolved absolute path...
> ```

**中文**：这是 shotgun 的技术核心——**用 Agent 工具实现真正的并行生成**。

```
并行架构示意：

主 Agent
    │
    ├──── Agent 子进程 A ────→ $D generate --brief "Corporate Clarity" --output /tmp/variant-A.png
    │                              ↓
    │                        质量检查 $D check
    │                              ↓
    │                        cp /tmp/variant-A.png ~/.gstack/.../variant-A.png
    │
    ├──── Agent 子进程 B ────→ $D generate --brief "Consumer Delight" --output /tmp/variant-B.png
    │                              ↓
    │                        （同步进行）
    │
    └──── Agent 子进程 C ────→ $D generate --brief "Minimalist Premium" --output /tmp/variant-C.png
                                   ↓
                             （同步进行）

所有子进程完成后，主 Agent 汇总结果
```

### 关键技术细节：`/tmp/` 再 `cp`

> **原文**：
> ```
> Why /tmp/ then cp? In observed sessions, `$D generate --output ~/.gstack/...`
> failed with "The operation was aborted" while `--output /tmp/...` succeeded. This is
> a sandbox restriction. Always generate to `/tmp/` first, then `cp`.
> ```

**中文**：这是从实际运行中发现的**沙箱限制**——AI 环境里，直接写入 `~/.gstack/` 有时会失败，但写入 `/tmp/` 总是成功。因此先写 `/tmp/`，再手动 `cp`。

这条规则直接出现在每个子 Agent 的 prompt 里，是从失败中学习的产物：

```
子 Agent Prompt 模板：
...
Steps:
1. Run: {$D path} generate --brief "{brief}" --output /tmp/variant-{letter}.png
   ← 写 /tmp/，不写 ~/.gstack/
2. If fails (429 or "rate limit"): wait 5s, retry up to 3 times
3. If output missing after success: retry once
4. Copy: cp /tmp/variant-{letter}.png {_DESIGN_DIR}/variant-{letter}.png
   ← 然后 cp 到目标位置
5. Quality check: {$D path} check --image ... --brief "..."
6. Verify: ls -lh {_DESIGN_DIR}/variant-{letter}.png
7. Report: VARIANT_{letter}_DONE: {size} 或 VARIANT_{letter}_FAILED: {error}
```

**错误处理层次**：
- 限流（429）：等 5 秒，重试，最多 3 次
- 文件为空：重试一次
- 质量检查失败：重试生成一次
- 完全失败：汇报 `VARIANT_X_FAILED`，不静默跳过

### Step 3d：结果汇总

> **原文**（第 787-808 行）：
> ```
> After all agents complete:
> 1. Read each generated PNG inline (Read tool) so the user sees all variants at once.
> 2. Report status: "All {N} variants generated in ~{actual time}..."
> 3. For any failures: report explicitly with the error. Do NOT silently skip.
> 4. If zero variants succeeded: fall back to sequential generation...
> ```

**中文**：汇总时几个关键点：

1. **内联显示**：所有 PNG 直接显示在 terminal 里（不只是文件路径），用户在浏览器打开前就能看到
2. **透明失败**：任何生成失败都明确报告，不静默跳过——"3 个变体里 1 个失败" vs 默默只展示 2 个
3. **全失败降级**：如果所有并行生成都失败，切换为串行生成（一个接一个），并告知用户"限流了，改顺序跑"
4. **动态图片列表**：比较板的图片列表从**实际存在的文件**动态构建，不硬编码 A/B/C

```bash
# 动态构建图片列表，而非硬编码
setopt +o nomatch 2>/dev/null || true
_IMAGES=$(ls "$_DESIGN_DIR"/variant-*.png 2>/dev/null | tr '\n' ',' | sed 's/,$//')
# _IMAGES = "~/.gstack/.../variant-A.png,~/.gstack/.../variant-B.png"
```

---

## Step 4：比较板 + 反馈循环

### 比较板工作原理

> **原文**（第 812-838 行）：
> ```bash
> $D compare --images "$_DESIGN_DIR/variant-A.png,..." --output "$_DESIGN_DIR/design-board.html" --serve
> ```
>
> This command generates the board HTML, starts an HTTP server on a random port,
> and opens it in the user's default browser. Run it in the background with `&`
> because the server needs to stay running while the user interacts with the board.
>
> Parse the port from stderr output: `SERVE_STARTED: port=XXXXX`.

**中文**：

```
比较板的结构：

┌─────────────────────────────────────────────────────────────────┐
│                    gstack Design Board                          │
│                                                                 │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │                │  │                │  │                │   │
│  │   Variant A    │  │   Variant B    │  │   Variant C    │   │
│  │                │  │                │  │                │   │
│  │  [PNG 图片]    │  │  [PNG 图片]    │  │  [PNG 图片]    │   │
│  │                │  │                │  │                │   │
│  └────────────────┘  └────────────────┘  └────────────────┘   │
│                                                                 │
│  ★★★★☆ Rate A    ★★★☆☆ Rate B    ★★★★★ Rate C              │
│                                                                 │
│  Comment A: _____________ Comment B: __ Comment C: _________   │
│                                                                 │
│  Overall direction: _______________________________________     │
│                                                                 │
│  [Regenerate some]  [More like B]  [Remix A+C]  [Submit ✓]    │
└─────────────────────────────────────────────────────────────────┘
```

比较板是一个真正的**交互式 Web 应用**（运行在 localhost 上），而不是静态 HTML。用户可以：
- 给每个变体打分（1-5 星）
- 对每个变体写评论
- 写整体反馈
- 点击 Regenerate（重新生成部分变体）
- 点击 More like B（生成更多类似 B 的变体）
- 点击 Remix（混合多个变体的特点）
- 点击 Submit（提交最终选择）

### 反馈 JSON 结构

```json
{
  "preferred": "A",
  "ratings": { "A": 4, "B": 3, "C": 2 },
  "comments": {
    "A": "Love the spacing",
    "B": "Colors are off",
    "C": "Too busy"
  },
  "overall": "Go with A, but make the CTA bigger",
  "regenerated": false
}
```

或在用户点击 Regenerate 时：

```json
{
  "preferred": null,
  "regenerateAction": "more_like_B",
  "remixSpec": null,
  "overall": "B is closest but too dark"
}
```

### 反馈文件检测逻辑

> **原文**（第 843-888 行）：
> ```bash
> if [ -f "$_DESIGN_DIR/feedback.json" ]; then
>   echo "SUBMIT_RECEIVED"
>   cat "$_DESIGN_DIR/feedback.json"
> elif [ -f "$_DESIGN_DIR/feedback-pending.json" ]; then
>   echo "REGENERATE_RECEIVED"
>   cat "$_DESIGN_DIR/feedback-pending.json"
>   rm "$_DESIGN_DIR/feedback-pending.json"
> else
>   echo "NO_FEEDBACK_FILE"
> fi
> ```

**三种路径**：

```
用户点击 Submit
    ↓
写 feedback.json
AI 读取 → 提取 preferred/ratings/comments
    ↓
确认 → 保存 approved.json → 结束

用户点击 Regenerate/More Like/Remix
    ↓
写 feedback-pending.json
AI 读取 regenerateAction
    ↓
生成新变体 → 更新比较板 → POST /api/reload（浏览器自动刷新）
    ↓
再次等待 AskUserQuestion

用户直接在 AskUserQuestion 里打字（没用板子）
    ↓
NO_FEEDBACK_FILE
AI 用文字回复作为反馈
```

> **为什么用文件而不是 WebSocket 或 SSE？**
> 文件是最简单、最可靠的进程间通信方式。浏览器页面写文件（通过 fetch POST 到 localhost server），AI 读文件，不需要建立持久连接。在 Cursor 的 AI 环境里，文件 I/O 比网络连接更稳定。

### Reload 机制

> **原文**（第 880-884 行）：
> ```bash
> curl -s -X POST http://127.0.0.1:PORT/api/reload \
>   -H 'Content-Type: application/json' \
>   -d '{"html":"$_DESIGN_DIR/design-board.html"}'
> ```

**中文**：当生成了新变体后，AI 通过这个 API 让浏览器里的比较板**自动刷新**，而不需要用户手动刷新或重新打开页面。体验是：你在浏览器里点了 Regenerate，60 秒后新图自动出现在同一个标签页里。

---

## Step 5：反馈确认

> **原文**（第 914-928 行）：
> ```
> "Here's what I understood from your feedback:
>
> PREFERRED: Variant [X]
> RATINGS: A: 4/5, B: 3/5, C: 2/5
> YOUR NOTES: [full text of per-variant and overall comments]
> DIRECTION: [regenerate action if any]
>
> Is this right?"
>
> Use AskUserQuestion to confirm before saving.
> ```

**中文**：AI 在保存 approved.json 之前，先把自己**理解到的内容**用结构化格式展示，让用户确认。

```
为什么这一步重要？

场景：
用户："我喜欢 A，但颜色能用 B 的吗？"
AI 理解："preferred: A，颜色参考 B"
用户心里："就是 A 的布局加 B 的颜色系"

如果 AI 直接保存了"preferred: A"然后 design-html 按 variant-A.png 直接实现
→ 少了颜色调整的信息
→ 下游工具不知道这个细节
→ 用户以为确认了就搞定了，结果 HTML 颜色不对

确认机制让信息损失变得可见。
```

---

## Step 6：保存 & 后续步骤

### approved.json 的结构

```bash
echo '{
  "approved_variant": "A",
  "feedback": "Love the spacing, use A colors",
  "date": "2024-01-15T10:30:00Z",
  "screen": "pricing-page",
  "branch": "feature/pricing-redesign"
}' > "$_DESIGN_DIR/approved.json"
```

**这个文件是 shotgun 和 html 之间的契约**——design-html 的 Step 0 会读取它，知道：
- 用哪个 PNG 作为视觉参考（`approved_variant: "A"` → `variant-A.png`）
- 用户的反馈意见（作为额外的设计指导）
- 这是哪个屏幕（`screen`）
- 在哪个分支上（`branch`）

### 后续步骤选项

> **原文**（第 937-943 行）：
> ```
> If standalone, offer next steps via AskUserQuestion:
>
> "Design direction locked in. What's next?
>  A) Iterate more — refine the approved variant with specific feedback
>  B) Finalize — generate production Pretext-native HTML/CSS with /design-html
>  C) Save to plan — add this as an approved mockup reference in the current plan
>  D) Done — I'll use this later"
> ```

**中文**：

| 选项 | 做什么 | 适合场景 |
|------|-------|---------|
| A) Iterate more | 继续调整选定变体 | 接近目标但还需要微调 |
| B) Finalize | 调用 /design-html 生成 HTML | 方向确定了，要代码了 |
| C) Save to plan | 在 plan 文件里引用这个 mockup | 有 CEO plan 需要更新 |
| D) Done | 结束 | 只是探索，稍后再用 |

---

## 重要规则解析

> **原文**（第 945-953 行）：
> ```
> Important Rules:
> 1. Never save to .context/, docs/designs/, or /tmp/.
>    All design artifacts go to ~/.gstack/projects/$SLUG/designs/.
> 2. Show variants inline before opening the board.
>    The user should see designs immediately in their terminal.
> 3. Confirm feedback before saving. Always summarize what you understood and verify.
> 4. Taste memory is automatic. Prior approved designs inform new generations by default.
> 5. Two rounds max on context gathering. Don't over-interrogate.
> ```

### 规则 1：存储路径强制

与 design-html 相同的路径规则——设计产物是**用户数据**，不是项目文件。

```
❌ 错误路径：
   .context/designs/variant-A.png      ← git 版本控制里
   docs/designs/variant-A.png          ← 项目目录里
   /tmp/variant-A.png                  ← 重启就没了

✅ 正确路径：
   ~/.gstack/projects/my-app/designs/pricing-20240115/variant-A.png
   ← 用户家目录，跨分支、跨会话持久存在
```

### 规则 2：内联显示 + 浏览器板双管齐下

```
设计：先在 terminal 里展示图片（Read 工具内联 PNG）
      再打开浏览器比较板

原因：
- 用户不一定立即看浏览器
- terminal 里能快速看到"3 个都生成了，大概长什么样"
- 浏览器板提供交互式打分和反馈
- 两个渠道，信息不会丢失
```

### 规则 3：口味记忆自动，可覆盖

口味记忆**默认启用**——AI 会偏向用户之前选过的风格。但用户可以覆盖：

```
触发覆盖：
"这次我想要完全不同的方向"
"给我一些 maximalist 的设计"
"忽略之前的选择，全新开始"

AI 行为：
不应用口味偏差，从 brief 出发自由生成
```

### 规则 4：上下文收集两轮上限

不管缺少多少信息，AI 最多问两轮，然后带着假设前进，并说明假设是什么。

```
第一轮：收集基本上下文
第二轮：补充关键缺失
第三轮：禁止。带着假设前进：
  "我假设：[假设列表]。如果这些不对，生成完之后告诉我。"
```

---

## 完整工作流总览

```
用户：/design-shotgun
          │
          ▼
Preamble: 环境初始化
          │
          ▼
DESIGN SETUP: 检测 $D, $B
  DESIGN_READY     → 使用 AI 图片生成
  DESIGN_NOT_AVAIL → 降级到 HTML wireframe
          │
          ▼
Step 0: 会话检测
  PREVIOUS_SESSIONS_FOUND → 显示历史，询问继续还是新探索
  NO_PREVIOUS_SESSIONS    → 显示首次欢迎消息
          │
          ▼
Step 1: 上下文收集（最多 2 轮）
  自动读取：DESIGN.md, src/目录, office-hours 文档, localhost 状态
  AskUserQuestion：只问缺失的部分
          │
          ▼
Step 2: 口味记忆
  读取历史 approved.json（最多 10 个）
  提取偏好：高对比度/无衬线/深色/等
  加入生成 brief
          │
          ▼
Step 3a: 概念生成
  N 个文字方向（A/B/C/...），每个是独特的创意方向
          │
          ▼
Step 3b: 概念确认
  AskUserQuestion：确认概念，允许修改（最多 2 轮）
          │
          ▼
Step 3c: 并行生成
  N 个 Agent 子进程同时执行
  每个：generate → quality check → cp 到目标目录
  总时间：~60s（不管几个变体）
          │
          ▼
Step 3d: 结果汇总
  内联显示所有 PNG
  报告成功/失败状态
  构建动态图片列表
          │
          ▼
Step 4: 比较板 + 反馈循环
  $D compare ... --serve → 打开浏览器比较板
  AskUserQuestion 等待用户反馈
          │
    ┌─────┴──────────────────────┐
    │                            │
feedback.json           feedback-pending.json
（用户点 Submit）        （用户点 Regenerate）
    │                            │
    ▼                            ▼
Step 5: 确认反馈          生成新变体
  结构化展示理解         POST /api/reload 刷新浏览器
  AskUserQuestion 确认   再次 AskUserQuestion
    │
    ▼
Step 6: 保存 approved.json
  → 提供后续步骤（iterate / 转 /design-html / 保存到 plan / 完成）
          │
          ▼
Telemetry: 记录执行时间和结果
```

---

## Shotgun vs Design-HTML 深度对比

| 维度 | /design-shotgun | /design-html |
|------|----------------|-------------|
| **核心工作** | 生成 AI 图片 mockup | 生成 HTML/CSS 代码 |
| **阶段** | 探索（发散） | 实现（收敛） |
| **工具** | $D（AI 图片生成） | Pretext（文本布局引擎） |
| **并行度** | 高（多个 Agent 并行生成变体） | 低（串行精化循环） |
| **迭代轮次** | 多轮（直到找到方向） | 最多 10 轮（精化已确定方向） |
| **反馈方式** | 浏览器交互式比较板 | AskUserQuestion 文字反馈 |
| **产物** | variant-*.png + approved.json | finalized.html + finalized.json |
| **是否写项目代码** | 否 | 是 |
| **allowed Edit** | 否 | 是 |
| **口味记忆** | 是（读取历史生成偏好） | 是（读取 approved.json 颜色/字体） |
| **依赖 $D** | 强依赖（核心功能） | 弱依赖（可降级） |
| **依赖 $B** | 可选（截图当前页） | 可选（截图验证视口） |

---

## 典型使用场景

### 场景 1：全新功能，从零开始

```
用户：/design-shotgun
AI：你有 DESIGN.md（蓝色主题，Inter 字体）。
    你之前没有设计过 dashboard 屏幕。
    你想要 dashboard 的什么功能？

用户：实时设备状态，按地区过滤，支持 1000+ 设备

AI：我来探索 3 个方向：
    A) "数据密集型" — 数据表为主，高信息密度，适合运维人员
    B) "地图可视化" — 地图为核心，设备分布一眼看清
    C) "健康卡片" — 卡片网格，状态颜色编码，快速扫描

→ 并行生成 → 打开比较板 → 用户选 B 加 C 的颜色 → approved.json
```

### 场景 2：已有设计但不满意

```
用户：我不喜欢现在的定价页面 /design-shotgun
AI：检测到 localhost:3000 在运行...
    截图当前定价页...

AI：我来生成 3 个改进方向（基于现有设计）：
    A) "更清晰的价格层级对比"
    B) "简化至 2 个方案，减少决策疲劳"
    C) "年付/月付切换置顶"

→ $D evolve --screenshot current.png → 打开比较板
```

### 场景 3：继续上次的探索

```
用户：/design-shotgun
AI：找到上次的探索：
    - 2024-01-14：landing-page — 选了 Variant A（高对比度黑白）
    - 2024-01-13：pricing-page — 选了 Variant C（消费者友好）

    A) 重新打开上次的比较板
    B) 新探索
    C) 其他

用户：A
→ 重建比较板 → 继续调整
```

---

## 关键设计决策汇总

| 设计决策 | 选择 | 理由 |
|---------|------|------|
| 命名 | "Shotgun" | 散弹枪比喻：多方向同时发射 |
| 并行生成 | Agent 工具 + 多子进程 | 固定时间内提供更多选择 |
| 图片先行 | 先文字概念 → 再图片 | 避免 API 浪费 |
| 反馈机制 | 浏览器比较板 + 文件 I/O | 比 AskUserQuestion 更直观 |
| 口味记忆 | 读历史 approved.json | 越用越懂用户审美 |
| 会话持久化 | ~/.gstack/ | 跨分支跨会话找到历史探索 |
| 降级策略 | $D 不可用 → HTML wireframe | 核心流程不依赖外部工具 |
| 上下文收集 | 自动 + 问缺口 + 2 轮上限 | 减少用户认知负担 |
| evolve 路径 | 截图 → $D evolve | "我不喜欢现有设计"也能用 |
| 确认环节 | 保存前展示理解 | 防止信息损失传递到 design-html |

---

---

## v0.17.0.0 新增：UX 行为基础（`{{UX_PRINCIPLES}}`）

v0.17.0.0 将 UX 行为原则（`{{UX_PRINCIPLES}}`）注入到 `/design-shotgun`，出现在 DESIGN SETUP 之后、Step 0（Session Detection）之前。

详细解读参见 [design-html.md 的 UX 原则章节](./design-html.md#v0170新增ux-原则用户实际行为ux_principles)。

### 在 `/design-shotgun` 中的具体应用

`/design-shotgun` 的核心任务是**生成设计变体**。UX 行为原则在这里的作用是：

**在生成 Brief 时自动过滤 AI Slop**

当 AI 构建 `$D generate --brief "..."` 的 Brief 时，UX 原则作为约束条件注入：

```
不好的 Brief（容易产生 AI Slop）：
  "现代 SaaS 落地页，三列特性网格，圆角卡片，渐变背景"

好的 Brief（UX 原则约束）：
  "落地页，一个清晰的视觉焦点，一个主要 CTA，
   用户能在 3 秒内明白这是什么产品，
   每个板块只做一件事，
   不要 3 列特性网格，不要装饰性 blob"
```

**在概念生成（Step 3a）时提供多样性约束**

UX 行为理论要求不同变体在不同维度上有所不同，而不只是配色/字体的微小变化：

```
好的 3 个方向（覆盖不同 UX 权衡）：
  A) 单屏 hero-first（最大化第一印象冲击）
  B) 导航优先（满足"用户满足即止"的跳转需求）
  C) 内容密集（满足"用户扫描"的信息获取需求）
```

**设计原理：为什么设计探索工具也需要 UX 行为理论？**

设计变体不只是"不同的视觉风格"，而应该是"不同的 UX 假设"。`{{UX_PRINCIPLES}}` 让 AI 在生成变体时有意识地探索不同的用户行为假设，而不是生成视觉上略有不同的同一个方案。

---

*本文档基于 `design-shotgun/SKILL.md`（1040 行）整理。与 `/design-html` 配合使用构成 gstack 完整设计工作流。*
