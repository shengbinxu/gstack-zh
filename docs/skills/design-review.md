# `/design-review` 技能逐段中英对照注解

> 对应源文件：`design-review/SKILL.md`（1596 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: design-review
preamble-tier: 4
version: 2.0.0
description: |
  Designer's eye QA: finds visual inconsistency, spacing issues, hierarchy problems,
  AI slop patterns, and slow interactions — then fixes them. Iteratively fixes issues
  in source code, committing each fix atomically and re-verifying with before/after
  screenshots. For plan-mode design review (before implementation), use /plan-design-review.
  Use when asked to "audit the design", "visual QA", "check if it looks good", or "design polish".
  Proactively suggest when the user mentions visual inconsistencies or
  wants to polish the look of a live site. (gstack)
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

- **name**: 技能名称。用户输入 `/design-review` 触发。
- **preamble-tier: 4**：最高级别 preamble（只有 /ship、/qa 等复杂技能用 tier 4）。包含完整的 Bash 环境初始化、升级检查、session 追踪、telemetry、路由注入、Vendoring 检测等。
- **description**：设计师眼光的 QA：发现视觉不一致、间距问题、层次结构问题、AI 生成风格模式和慢交互——然后修复它们。在源代码中逐个修复问题，原子式提交，并用 before/after 截图重新验证。
- **allowed-tools**: 注意包含了 **Edit**——这是与 `/plan-design-review` 的关键区别：设计审查阶段会**真正修改源代码**，不只是评审。

> **设计原理：为什么有 Edit？**
> `/design-review` 是实现后的审查，不仅找问题还要修问题。每个修复都有 before/after 截图证明。这是"审计+修复"一体化——不像传统的评审工具只生成报告让开发者自己修。

---

## 与 `/plan-design-review` 的核心区别

| 维度 | `/design-review` | `/plan-design-review` |
|------|-----------------|----------------------|
| 阶段 | 实现后（live site） | 实现前（plan 文档） |
| 输入 | 运行中的网站/应用 | 方案文档（Markdown） |
| 输出 | 源码修复 + before/after 截图 | 更完整的设计方案 |
| 核心工具 | `$B`（headless browser） | `$D`（design mockup generator） |
| 提交 | `git commit` 每个修复 | 编辑 plan 文件 |
| 触发时机 | "check if it looks good" | "review the design plan" |

```
软件开发时间线：

  idea → plan → implement → [design-review] → ship
              ↑                 ↑
    plan-design-review    design-review
     (在这里介入)          (在这里介入)
```

---

## Preamble（前置运行区）— Tier 4

Tier 4 是最完整的 preamble，包含约 450 行初始化代码。以下是关键部分解析：

### 环境初始化脚本

> **原文（节选）**：
> ```bash
> _UPD=$(~/.claude/skills/gstack/bin/gstack-update-check 2>/dev/null || ...)
> mkdir -p ~/.gstack/sessions
> touch ~/.gstack/sessions/"$PPID"
> _PROACTIVE=$(~/.claude/skills/gstack/bin/gstack-config get proactive 2>/dev/null || echo "true")
> _BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
> echo "BRANCH: $_BRANCH"
> ```

**中文**：检查更新、记录 session、读取配置项（proactive 模式、skill 前缀、PROACTIVE_PROMPTED 等）、检测当前 git 分支。这些输出供后续条件逻辑使用。

### Telemetry 系统

```bash
echo '{"skill":"design-review","ts":"...","repo":"..."}'  >> ~/.gstack/analytics/skill-usage.jsonl
```

**中文**：仅当 telemetry 不是 off 时，记录技能使用到本地 JSONL 文件。**不发送代码或文件路径**，只记录使用了哪个技能、在哪个仓库。这是 gstack 改进的数据基础。

### 运行模式检测

> **原文**：
> ```
> If `PROACTIVE` is `"false"`, do not proactively suggest gstack skills AND do not
> auto-invoke skills based on conversation context. Only run skills the user explicitly
> types (e.g., /qa, /ship).
> ```

**中文**：如果 PROACTIVE 为 false，不主动建议 gstack 技能，不根据对话上下文自动调用技能。只运行用户明确输入的命令（如 /qa、/ship）。

> **设计原理**：尊重用户主权。有些用户不希望 AI 主动插手——他们要全程掌控节奏。Proactive 模式是可关闭的。

### Boil the Lake 原则

> **原文**：
> ```
> If `LAKE_INTRO` is `no`: Before continuing, introduce the Completeness Principle.
> Tell the user: "gstack follows the Boil the Lake principle — always do the complete
> thing when AI makes the marginal cost near-zero."
> ```

**中文**：如果用户第一次使用 gstack，在继续之前介绍完整性原则："gstack 遵循'煮沸湖泊'原则——当 AI 使边际成本接近零时，总是做完整的事情。"

> **设计原理**：这是 gstack 的核心哲学。传统开发"做够用就行"，但有了 AI，完整的工作（所有边界情况、所有测试、所有设计细节）几乎不额外花费人力。所以 gstack 默认推荐完整方案，而不是 MVP 式的妥协。

---

## `/design-review` 技能主体：审计→修复→验证

> **原文**：
> ```
> # /design-review: Design Audit → Fix → Verify
>
> You are a senior product designer AND a frontend engineer. Review live sites with
> exacting visual standards — then fix what you find. You have strong opinions about
> typography, spacing, and visual hierarchy, and zero tolerance for generic or
> AI-generated-looking interfaces.
> ```

**中文**：你是一位高级产品设计师，同时也是前端工程师。以严苛的视觉标准审查运行中的网站——然后修复你发现的问题。对排版、间距和视觉层次结构有强烈的主见，对通用或 AI 生成感的界面零容忍。

> **设计原理**：角色设定是"设计师 + 工程师"二合一——不只是"看起来不错"，也不只是"代码可以运行"。这两个视角结合才能产出真正有价值的设计审查。

---

## Setup（初始化设置）

### 参数解析

> **原文**：
> ```
> Parse the user's request for these parameters:
> | Parameter | Default | Override example |
> |-----------|---------|-----------------|
> | Target URL | (auto-detect or ask) | https://myapp.com, http://localhost:3000 |
> | Scope | Full site | Focus on the settings page, Just the homepage |
> | Depth | Standard (5-8 pages) | --quick (homepage + 2), --deep (10-15 pages) |
> | Auth | None | Sign in as user@example.com, Import cookies |
> ```

**中文**：解析用户请求中的参数：目标 URL（自动检测或询问）、审查范围（整站/特定页面）、深度（标准 5-8 页 / --quick / --deep）、认证方式（无 / 注入 Cookie）。

### Diff-aware 模式

> **原文**：
> ```
> If no URL is given and you're on a feature branch: Automatically enter diff-aware mode.
> When on a feature branch, scope to pages affected by the branch changes:
> 1. Analyze the branch diff: git diff main...HEAD --name-only
> 2. Map changed files to affected pages/routes
> 3. Detect running app on common local ports (3000, 4000, 8080)
> 4. Audit only affected pages, compare design quality before/after
> ```

**中文**：如果在 feature 分支且没有给出 URL，自动进入差异感知模式。分析分支变更文件，映射到受影响的页面/路由，只审计受影响的页面，对比前后设计质量。

> **设计原理**：聪明的范围控制。不需要每次都审计整个网站——如果只改了一个组件，只看那个组件的相关页面就够了。这让 design-review 快得多，也减少噪音。

### CDP 模式检测

```bash
$B status 2>/dev/null | grep -q "Mode: cdp" && echo "CDP_MODE=true" || echo "CDP_MODE=false"
```

**中文**：检查 browse 是否连接到用户的真实浏览器（CDP 模式）。如果是，跳过 cookie 导入步骤——真实浏览器已经有 cookie 和认证 session。

### DESIGN.md 检查

> **原文**：
> ```
> Look for DESIGN.md, design-system.md, or similar in the repo root. If found, read it —
> all design decisions must be calibrated against it. Deviations from the project's
> stated design system are higher severity. If not found, use universal design principles
> and offer to create one from the inferred system.
> ```

**中文**：在仓库根目录查找 `DESIGN.md`、`design-system.md` 或类似文件。如果找到，读取它——所有设计决策必须根据它进行校准。偏离项目声明的设计系统的问题严重性更高。

> **设计原理**：DESIGN.md 是设计系统的"单一真相来源"。有了它，审查不是凭直觉，而是对照标准。没有 DESIGN.md 的项目，/design-review 的发现需要靠通用原则，效果稍弱——这也是为什么 gstack 推荐先运行 `/design-consultation`。

### 工作区检查（Clean Working Tree）

```bash
git status --porcelain
```

> **原文**：
> ```
> If the output is non-empty (working tree is dirty), STOP and use AskUserQuestion:
> "Your working tree has uncommitted changes. /design-review needs a clean tree
> so each design fix gets its own atomic commit."
> Options:
> - A) Commit my changes
> - B) Stash my changes
> - C) Abort
> ```

**中文**：如果工作区有未提交的改动，停止并询问用户。选项：A) 提交当前改动，B) Stash 当前改动，C) 中止。

> **设计原理**：原子提交原则。每个设计修复必须是独立的 git commit，这样可以精确追踪每个改动的效果，也方便回滚单个修复。如果工作区不干净，原子提交就无法保证。

---

## 核心流程图

```
用户输入 /design-review
         │
         ▼
    ┌─────────────┐
    │  Preamble   │  初始化环境、检查升级、读取配置
    └──────┬──────┘
           │
           ▼
    ┌─────────────┐
    │   Setup     │  解析参数、检测 CDP 模式
    │             │  读取 DESIGN.md、检查工作区干净
    └──────┬──────┘
           │
           ▼
    ┌─────────────┐
    │  Browse     │  初始化 headless browser ($B)
    │  Setup      │  初始化 design binary ($D)
    └──────┬──────┘
           │
           ▼
    ┌─────────────────────────────────────────┐
    │           审计阶段 (Phases 1-6)          │
    │                                         │
    │  Phase 1: First Impression              │
    │    截图 → 写第一印象结构化评价            │
    │                                         │
    │  Phase 2: Design System Extraction      │
    │    提取字体、颜色、标题层级、间距模式      │
    │                                         │
    │  Phase 3: Page-by-Page Visual Audit     │
    │    逐页截图 → 80条审查清单               │
    │                                         │
    │  Phase 4: Interaction Flow Review       │
    │    走 2-3 个关键用户流程               │
    │                                         │
    │  Phase 5: Cross-Page Consistency       │
    │    跨页面一致性对比                     │
    │                                         │
    │  Phase 6: Compile Report               │
    │    生成报告、计算分数（A-F）            │
    └──────────────┬──────────────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────────────┐
    │    Design Outside Voices（可选）         │
    │    Codex 设计评审 + Claude 子代理        │
    └──────────────┬──────────────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────────────┐
    │           Phase 7: Triage               │
    │    按 High / Medium / Polish 分级        │
    └──────────────┬──────────────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────────────┐
    │        Phase 8: Fix Loop               │
    │                                         │
    │  8a. Locate source（定位源码）           │
    │  8a.5. Target Mockup（生成目标效果图）   │
    │  8b. Fix（最小化修复）                  │
    │  8c. Commit（原子提交）                 │
    │  8d. Re-test（重新验证）                │
    │  8e. Classify（验证/尽力/回滚）          │
    │  8e.5. Regression Test（JS 修复才需要）  │
    │  8f. Self-Regulation（每5个修复评估风险）│
    │                                         │
    │  ←────── 循环直到所有可修复项完成 ──────→ │
    └──────────────┬──────────────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────────────┐
    │        Phase 9: Final Design Audit      │
    │    重新审计、计算最终分数                │
    └──────────────┬──────────────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────────────┐
    │        Phase 10: Report                 │
    │    写报告到 ~/.gstack/projects/$SLUG     │
    └──────────────┬──────────────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────────────┐
    │        Phase 11: TODOS.md Update        │
    │    未修复的发现写入 TODOS.md             │
    └─────────────────────────────────────────┘
```

---

## Phase 1：第一印象（First Impression）

> **原文**：
> ```
> The most uniquely designer-like output. Form a gut reaction before analyzing anything.
>
> 1. Navigate to the target URL
> 2. Take a full-page desktop screenshot
> 3. Write the First Impression using this structured critique format:
>    - "The site communicates [what]."
>    - "I notice [observation]."
>    - "The first 3 things my eye goes to are: [1], [2], [3]."
>    - "If I had to describe this in one word: [word]."
>
> This is the section users read first. Be opinionated. A designer doesn't hedge — they react.
> ```

**中文**：最具设计师特质的输出。在分析任何东西之前先形成直觉反应。四句结构化评价：1）网站传递了什么？2）我注意到什么？3）眼睛先看到的前三件事是什么？4）用一个词描述它是什么？

> **设计原理**：第一印象是用户真实体验的近似。大多数用户在 5 秒内就决定"这个东西靠谱吗"。结构化的第一印象强迫 AI 不躲在分析后面——直接给出一个有立场的判断。"A designer doesn't hedge — they react."

---

## Phase 2：设计系统提取（Design System Extraction）

> **原文**：
> ```bash
> # Fonts in use (capped at 500 elements to avoid timeout)
> $B js "JSON.stringify([...new Set([...document.querySelectorAll('*')].slice(0,500).map(e => getComputedStyle(e).fontFamily))])"
>
> # Color palette in use
> $B js "JSON.stringify([...new Set([...document.querySelectorAll('*')].slice(0,500).flatMap(e => [getComputedStyle(e).color, getComputedStyle(e).backgroundColor])...)])"
>
> # Heading hierarchy
> $B js "JSON.stringify([...document.querySelectorAll('h1,h2,h3,h4,h5,h6')].map(h => ({tag, text, size, weight})))"
>
> # Touch target audit
> $B js "...filter(e => r.width > 0 && (r.width < 44 || r.height < 44))..."
>
> # Performance baseline
> $B perf
> ```

**中文**：通过 JavaScript 注入，从实际渲染的 DOM 中提取设计系统：使用中的字体列表、颜色调色板、标题层级、间距模式。同时检测小于 44px 的触控目标（可访问性要求）。

提取结果结构化为**推断的设计系统**：
- **字体**：列出各字体及使用次数。超过 3 种字族则标记。
- **颜色**：提取调色板。超过 12 种非灰色则标记。
- **标题比例**：h1-h6 尺寸。跳级或非系统性跳跃则标记。
- **间距模式**：抽样 padding/margin 值。非比例尺值则标记。

> **设计原理**："提取真实渲染的设计系统"，不是看 DESIGN.md 说什么，而是看浏览器实际渲染了什么。两者的差距就是执行偏差——设计文档和实现之间的裂缝。

---

## Phase 3：逐页视觉审计（80 项清单）

核心命令：
```bash
$B goto <url>
$B snapshot -i -a -o "$REPORT_DIR/screenshots/{page}-annotated.png"  # 带注解截图
$B responsive "$REPORT_DIR/screenshots/{page}"  # 响应式截图（移动/平板/桌面）
$B console --errors  # 控制台错误
$B perf  # 性能数据
```

### 10 大类、80 条审查清单

#### 1. 视觉层次与构图（Visual Hierarchy & Composition，8项）

- 是否有明确的焦点？每个视图是否只有一个主要 CTA？
- 视觉流动是否自然（左上→右下）？
- 是否有视觉噪音——多个元素互相争夺注意力？
- 眯眼测试：模糊状态下层次结构是否仍然可见？
- 空白是否刻意，而不是"剩下的"？

#### 2. 排版（Typography，15项）

> **原文**（部分）：
> ```
> - Font count <=3 (flag if more)
> - Scale follows ratio (1.25 major third or 1.333 perfect fourth)
> - Line-height: 1.5x body, 1.15-1.25x headings
> - Measure: 45-75 chars per line (66 ideal)
> - Heading hierarchy: no skipped levels (h1→h3 without h2)
> - Weight contrast: >=2 weights used for hierarchy
> - No blacklisted fonts (Papyrus, Comic Sans, Lobster, Impact, Jokerman)
> - If primary font is Inter/Roboto/Open Sans/Poppins → flag as potentially generic
> - text-wrap: balance or text-pretty on headings
> - Curly quotes used, not straight quotes
> - font-variant-numeric: tabular-nums on number columns
> - Body text >= 16px, Caption/label >= 12px
> - No letterspacing on lowercase text
> ```

**中文要点**：
- 字体不超过 3 种，否则标记
- 比例遵循 1.25 大三度或 1.333 纯四度音阶
- 行高：正文 1.5x，标题 1.15-1.25x
- 每行 45-75 字符（66 字符最理想）
- 标题层级不跳级（不能 h1→h3 跳过 h2）
- Inter/Roboto/Open Sans/Poppins 被标记为"可能通用"
- 弯引号而非直引号，省略号字符而非三个点

> **为什么这么细？** 字体决策是设计系统的脊骨。Inter 用了 80% 的 SaaS 产品，用 Inter 本身没错，但如果你的设计看起来跟所有人一样，那就需要在其他维度上找到差异化。

#### 3. 颜色与对比度（Color & Contrast，10项）

- WCAG AA 标准：正文文字 4.5:1，大文字（18px+）3:1
- 语义色一致（成功=绿，错误=红，警告=黄/琥珀）
- 不允许只靠颜色编码信息（总要加标签、图标或图案）
- 暗模式：使用 elevation 而非简单反转亮度
- 暗模式文字颜色：接近白色（~#E0E0E0），不是纯白

#### 4. 间距与布局（Spacing & Layout，12项）

- 间距遵循比例尺（4px 或 8px 基础），不使用任意值
- 内圆角半径 = 外圆角半径 - 间距（嵌套元素）
- 移动端无水平滚动
- 最大内容宽度已设置（正文不全幅显示）

#### 5. 交互状态（Interaction States，10项）

> **原文**：
> ```
> - Hover state on all interactive elements
> - focus-visible ring present (never outline: none without replacement)
> - Active/pressed state with depth effect or color shift
> - Disabled state: reduced opacity + cursor: not-allowed
> - Loading: skeleton shapes match real content layout
> - Empty states: warm message + primary action + visual (not just "No items.")
> - Error messages: specific + include fix/next step
> - Touch targets >= 44px on all interactive elements
> ```

**中文**：每个交互元素必须有 hover 状态；`focus-visible` 环不能被 `outline: none` 移除；空状态不能只是 "No items."——需要温暖的文案 + 主要操作 + 视觉元素；错误消息要具体，包含修复/下一步。

> **设计原理**：交互状态是设计的"边界情况"。大多数 AI 生成的界面只设计了 happy path——所有东西都填满、加载完成。真实用户遇到空状态、错误、加载中、禁用状态。这些状态的设计质量直接决定用户信任度。

#### 6. 响应式设计（Responsive Design，8项）

- 移动端布局在设计层面有意义（不只是把桌面列堆叠起来）
- 不允许 `user-scalable=no` 或 `maximum-scale=1`（阻止用户缩放）

#### 7. 动效与动画（Motion & Animation，6项）

- 缓动：进入用 ease-out，退出用 ease-in，移动用 ease-in-out
- 时长：50-700ms 范围
- 遵守 `prefers-reduced-motion`
- 不允许 `transition: all`——明确列出属性
- 只对 `transform` 和 `opacity` 做动画（不对 width、height、top 等布局属性）

#### 8. 内容与微文案（Content & Microcopy，8项）

> **原文**：
> ```
> - Button labels specific ("Save API Key" not "Continue" or "Submit")
> - No placeholder/lorem ipsum text visible in production
> - Active voice ("Install the CLI" not "The CLI will be installed")
> - Loading states end with "…" ("Saving…" not "Saving...")
> - Destructive actions have confirmation modal or undo window
> ```

**中文**：按钮标签要具体（"保存 API Key"而非"继续"）；使用主动语态；加载状态末尾用省略号字符（`…`）而非三个点（`...`）；破坏性操作需要确认对话框或撤销窗口。

---

## 第 9 类：AI Slop 检测（gstack 独有概念）

这是 `/design-review` 最具辨识度的功能。

> **原文**：
> ```
> **9. AI Slop Detection** (10 anti-patterns — the blacklist)
>
> The test: would a human designer at a respected studio ever ship this?
>
> 1. Purple/violet/indigo gradient backgrounds or blue-to-purple color schemes
> 2. The 3-column feature grid: icon-in-colored-circle + bold title + 2-line description,
>    repeated 3x symmetrically. THE most recognizable AI layout.
> 3. Icons in colored circles as section decoration (SaaS starter template look)
> 4. Centered everything (text-align: center on all headings, descriptions, cards)
> 5. Uniform bubbly border-radius on every element
> 6. Decorative blobs, floating circles, wavy SVG dividers
> 7. Emoji as design elements (rockets in headings, emoji as bullet points)
> 8. Colored left-border on cards (border-left: 3px solid <accent>)
> 9. Generic hero copy ("Welcome to [X]", "Unlock the power of...")
> 10. Cookie-cutter section rhythm (hero → 3 features → testimonials → pricing → CTA)
> ```

**测试标准**："一个受人尊重的设计工作室的人类设计师会发布这个吗？"

**10 条 AI 生成反模式黑名单**：

| # | 反模式 | 描述 |
|---|--------|------|
| 1 | 渐变背景 | 紫/紫罗兰/靛蓝渐变，蓝→紫配色 |
| 2 | **3列特性网格** | 彩色圆圈图标 + 粗体标题 + 2行描述，3次对称重复。**最标志性的 AI 布局** |
| 3 | 装饰性圆圈图标 | 图标放在彩色圆圈里作为装饰 |
| 4 | 万物居中 | `text-align: center` 用在所有标题、描述、卡片上 |
| 5 | 统一圆角 | 每个元素都用一样的大圆角 |
| 6 | 装饰性形状 | blob、浮动圆圈、波浪 SVG 分割线 |
| 7 | emoji 作设计元素 | 标题里放火箭，子弹点用 emoji |
| 8 | 彩色左边框卡片 | `border-left: 3px solid <accent>` |
| 9 | 通用英雄文案 | "Welcome to [X]", "Unlock the power of..." |
| 10 | 模板化节奏 | hero→3特性→证言→定价→CTA，每节同样高度 |

> **来源**：[OpenAI "Designing Delightful Frontends with GPT-5.4"](https://developers.openai.com/blog/designing-delightful-frontends-with-gpt-5-4)（2026年3月）+ gstack 设计方法论。

> **设计原理**：AI Slop 是 2024-2026 年 SaaS 产品的通病。Claude/GPT 生成的代码默认会用这些模式，因为训练数据中充斥着它们。人类设计师在工作室里不会接受这些——但开发者自己不容易识别。`/design-review` 的 AI Slop 检测填补了这个视角缺口。

---

## 评分系统

> **原文**：
> ```
> Dual headline scores:
> - Design Score: {A-F} — weighted average of all 10 categories
> - AI Slop Score: {A-F} — standalone grade with pithy verdict
>
> Per-category grades:
> - A: Intentional, polished, delightful. Shows design thinking.
> - B: Solid fundamentals, minor inconsistencies. Looks professional.
> - C: Functional but generic. No major problems, no design point of view.
> - D: Noticeable problems. Feels unfinished or careless.
> - F: Actively hurting user experience. Needs significant rework.
> ```

**双标题分数**：
- **设计分 {A-F}**：10 个类别的加权平均
- **AI Slop 分 {A-F}**：独立评分，附简洁评语

| 等级 | 含义 |
|------|------|
| A | 刻意的、精细的、令人愉悦的，展现出设计思维 |
| B | 基础扎实，有小的不一致，看起来专业 |
| C | 功能正常但通用，没有重大问题，也没有设计立场 |
| D | 明显问题，感觉未完成或粗心 |
| F | 积极损害用户体验，需要大量返工 |

**分数计算规则**：
- 每个类别从 A 开始
- 每个高影响发现：降一个字母等级
- 每个中等影响发现：降半个字母等级
- 润色发现：记录但不影响等级

**各类别权重**：

| 类别 | 权重 |
|------|------|
| 视觉层次 | 15% |
| 排版 | 15% |
| 间距与布局 | 15% |
| 颜色与对比度 | 10% |
| 交互状态 | 10% |
| 响应式 | 10% |
| 内容质量 | 10% |
| AI Slop | 5% |
| 动效 | 5% |
| 性能感知 | 5% |

> AI Slop 只占 5% 的设计分，但作为独立标题指标单独评分——因为它传递的信号不同：你的网站是否"感觉像机器生成的"。

---

## Phase 4：交互流程审查

> **原文**：
> ```
> Walk 2-3 key user flows and evaluate the feel, not just the function:
>
> $B snapshot -i
> $B click @e3           # perform action
> $B snapshot -D          # diff to see what changed
>
> Evaluate:
> - Response feel: Does clicking feel responsive? Any delays or missing loading states?
> - Transition quality: Are transitions intentional or generic/absent?
> - Feedback clarity: Did the action clearly succeed or fail? Is the feedback immediate?
> - Form polish: Focus states visible? Validation timing correct? Errors near the source?
> ```

**中文**：走 2-3 个关键用户流程，评价"感觉"，不只是"功能"。用 snapshot diff（`-D`）查看每个操作后页面发生了什么变化。关注：响应感（点击是否即时响应？）、过渡质量（过渡是刻意的还是通用的/缺失的？）、反馈清晰度（操作成功还是失败是否清楚？）、表单打磨（焦点状态可见？验证时机正确？）

---

## Phase 7：分级（Triage）

> **原文**：
> ```
> - High Impact: Fix first. These affect the first impression and hurt user trust.
> - Medium Impact: Fix next. These reduce polish and are felt subconsciously.
> - Polish: Fix if time allows. These separate good from great.
>
> Mark findings that cannot be fixed from source code as "deferred" regardless of impact.
> ```

**三级影响分类**：
- **高影响**：首先修复。影响第一印象，损害用户信任。
- **中等影响**：接下来修复。降低打磨度，被用户潜意识感受到。
- **润色**：有时间就修复。区分好与卓越。

无法从源代码修复的问题（如第三方组件问题、需要团队提供文案的内容问题）标记为"延期"。

---

## Phase 8：修复循环（Fix Loop）

这是 `/design-review` 与传统设计审查工具最大的不同——它不只报告问题，它修复问题。

### 8a. 定位源码

```bash
# 搜索 CSS 类名、组件名、样式文件
# Glob 匹配受影响页面的文件模式
```

规则：**只修改与发现直接相关的文件**，优先 CSS/样式改动而非结构改动。

### 8a.5. 生成目标效果图（如果 DESIGN_READY）

```bash
$D generate --brief "<修复后页面/组件的描述，参考 DESIGN.md 约束>" \
    --output "$REPORT_DIR/screenshots/finding-NNN-target.png"
```

向用户展示："这是当前状态（截图），这是应该是什么样子（效果图）。现在我来修复源码以匹配它。"

> **设计原理**：这让"当前设计"与"目标设计"之间的差距变得直观，而不抽象。文字描述"间距太宽"不如一张"这是它应该看起来的样子"的图片。

### 8b. 最小化修复

> **原文**：
> ```
> Make the minimal fix — smallest change that resolves the design issue
> CSS-only changes are preferred (safer, more reversible)
> Do NOT refactor surrounding code, add features, or "improve" unrelated things
> ```

**中文**：最小化修复——解决设计问题的最小改动。CSS-only 改动优先（更安全，更可逆）。**不重构周围代码，不添加功能，不"改进"不相关的东西**。

> **设计原理**：克制原则。设计师会想"既然在这里，就把所有东西都改好"，但这增加了风险并使 git 历史模糊。每次只做一件事，每件事都有证据。

### 8c. 原子提交

```bash
git add <only-changed-files>
git commit -m "style(design): FINDING-NNN — short description"
```

- **每个修复一个提交**，永不捆绑多个修复
- 消息格式：`style(design): FINDING-NNN — 简短描述`

### 8d. 重新测试

```bash
$B goto <affected-url>
$B screenshot "$REPORT_DIR/screenshots/finding-NNN-after.png"
$B console --errors
$B snapshot -D  # diff 显示什么变了
```

**每个修复必须有 before/after 截图对**。

### 8e. 分类结果

- **verified**：重新测试确认修复有效，没有引入新错误
- **best-effort**：修复已应用，但无法完全验证（如需要特定浏览器状态）
- **reverted**：检测到回归 → `git revert HEAD` → 标记发现为"延期"

### 8f. 自我调节（风险计算）

> **原文**：
> ```
> DESIGN-FIX RISK:
>   Start at 0%
>   Each revert:                        +15%
>   Each CSS-only file change:          +0%
>   Each JSX/TSX/component file change: +5% per file
>   After fix 10:                       +1% per additional fix
>   Touching unrelated files:           +20%
>
> If risk > 20%: STOP immediately.
> Hard cap: 30 fixes. After 30 fixes, stop regardless.
> ```

**中文**：每 5 个修复（或任何回滚后），计算设计修复风险等级。风险超过 20% 立即停止，向用户展示已完成的工作。硬上限：30 个修复，无论如何都停止。

> **设计原理**：风险感知机制防止 AI 陷入"越修越坏"的循环。CSS-only 修改风险为 0%（只影响样式），JSX 组件修改风险 +5%（可能破坏逻辑），触碰不相关文件 +20%（范围蔓延的危险信号）。

---

## Design Outside Voices（外部设计声音）

在 `/design-review` 中，外部声音是**自动运行的**（如果 Codex 可用）：

> **原文**：
> ```
> Automatic: Outside voices run automatically when Codex is available. No opt-in needed.
> ```

会同时启动两个声音：

1. **Codex 设计声音**（通过 Bash 执行）：
   - 对源代码进行 `read-only` 模式的设计审查
   - 检查：间距是否系统化？字体是否有表达力？响应式断点？无障碍性？
   - 应用 Hard Rules：营销页规则 vs App UI 规则

2. **Claude 设计子代理**（通过 Agent 工具）：
   - 独立的高级产品设计师审查
   - 专注于跨文件的**一致性模式**：间距值是否在整个代码库中系统化？是否只有一个颜色系统？

**合并 Litmus 计分卡**：

```
DESIGN OUTSIDE VOICES — LITMUS SCORECARD:
═══════════════════════════════════════════════════════════════
  Check                                    Claude  Codex  Consensus
  ─────────────────────────────────────── ─────── ─────── ─────────
  1. Brand unmistakable in first screen?   YES     YES    CONFIRMED
  2. One strong visual anchor?             YES     NO     DISAGREE
  3. Scannable by headlines only?          YES     YES    CONFIRMED
  ...
═══════════════════════════════════════════════════════════════
```

填入每个单元格的值：CONFIRMED（双方同意）、DISAGREE（模型意见不同）、NOT SPEC'D（信息不足）。

---

## 重要规则（Important Rules）

> **原文（11条规则）**：
> ```
> 1. Think like a designer, not a QA engineer.
> 2. Screenshots are evidence. Every finding needs at least one screenshot.
> 3. Be specific and actionable. "Change X to Y because Z" — not "the spacing feels off."
> 4. Never read source code. Evaluate the rendered site, not the implementation.
> 5. AI Slop detection is your superpower.
> 6. Quick wins matter. Always include "Quick Wins" section — 3-5 highest-impact fixes.
> 7. Use snapshot -C for tricky UIs.
> 8. Responsive is design, not just "not broken."
> 9. Document incrementally. Write each finding to the report as you find it.
> 10. Depth over breadth. 5-10 well-documented findings > 20 vague observations.
> 11. Show screenshots to the user. After every screenshot command, use Read tool.
> ```

**关键设计原则**：

- **规则 3**："Change X to Y because Z"——不是"间距感觉不对"，而是"将 `padding: 24px` 改为 `padding: 16px`，因为与 8px 基础比例尺对齐"
- **规则 4**：永远不要直接读源代码来评判设计——评价渲染的网站，不是实现。（例外：提供创建 DESIGN.md 的帮助时。）
- **规则 8**：响应式是设计，不只是"没有破"。把桌面列堆叠到移动端不是响应式设计——那是懒惰。
- **规则 11**：每次截图命令后都用 Read 工具展示图片给用户——否则截图对用户不可见。

---

## 运行模式对比

| 模式 | 触发方式 | 页面数 | 清单评估 | 响应式截图 | 主要用途 |
|------|---------|--------|----------|-----------|--------|
| Quick (`--quick`) | `--quick` 参数 | 首页+2页 | 缩略版 | 是 | 快速获取设计评分 |
| Standard（默认） | 无参数 | 5-8页 | 完整清单 | 是 | 常规设计审查 |
| Deep (`--deep`) | `--deep` 参数 | 10-15页 | 全面 | 是 | 预发布审计/大型重设计 |
| Diff-aware | feature 分支+无URL | 受影响页面 | 完整清单 | 是 | 功能分支设计审查 |
| Regression | `--regression` 或存在 baseline | 全站 | 完整+对比 | 是 | 验证是否有设计回归 |

---

## 输出目录结构

```
~/.gstack/projects/$SLUG/designs/design-audit-{YYYYMMDD}/
├── design-audit-{domain}.md           # 结构化报告
├── screenshots/
│   ├── first-impression.png            # Phase 1 第一印象
│   ├── {page}-annotated.png            # 带注解的逐页截图
│   ├── {page}-mobile.png               # 响应式截图
│   ├── {page}-tablet.png
│   ├── {page}-desktop.png
│   ├── finding-001-before.png          # 修复前截图
│   ├── finding-001-target.png          # 目标效果图（如果生成了）
│   ├── finding-001-after.png           # 修复后截图
│   └── ...
└── design-baseline.json                # 用于回归模式
```

---

## Design Critique Format（设计评价格式）

> **原文**：
> ```
> - "I notice..." — observation
> - "I wonder..." — question
> - "What if..." — suggestion
> - "I think... because..." — reasoned opinion
> ```

**四种表达方式**：
- "我注意到..."——观察（中性描述）
- "我想知道..."——疑问（引发思考）
- "如果..."——建议（开放性方案）
- "我认为...因为..."——有推理的立场

> **设计原理**：这种结构来自设计批评的传统实践（Liz Lerman 的批评工作坊）。直接的判断（"这很糟糕"）会引发防御反应；结构化的表达让对话更有成效。但注意：gstack 并不回避直接判断，"Well-designed" 或 "this is a mess" 都是允许的——关键是把判断和推理一起给出。

---

## 额外规则（Additional Rules for design-review）

> **原文**：
> ```
> 11. Clean working tree required.
> 12. One commit per fix. Never bundle multiple design fixes into one commit.
> 13. Only modify tests when generating regression tests in Phase 8e.5.
>     Never modify CI configuration.
> ```

**中文**：
- 干净工作树是前提（通过 git status 检查）
- 每个修复一个提交，永不捆绑
- 只在 Phase 8e.5 生成回归测试时才修改测试。永远不要修改 CI 配置。

---

## 与 `/qa` 的区别

| 维度 | `/design-review` | `/qa` |
|------|-----------------|-------|
| 评审视角 | 设计师眼光 | QA 工程师眼光 |
| 发现类型 | 视觉问题、AI 风格模式、设计不一致 | 功能 bug、错误、崩溃 |
| 截图用途 | 每个发现的证据 + before/after | 复现步骤的证据 |
| 提交格式 | `style(design): FINDING-NNN` | `fix: FINDING-NNN` |
| 回归测试 | 只对 JS 行为修复（CSS 修复无需测试） | 每个修复都生成回归测试 |
| 主要工具 | `$B`（浏览器截图）+ `$D`（效果图生成） | `$B`（浏览器交互）+ 测试框架 |

---

## 总结：design-review 的核心价值

```
传统设计审查：
  设计师发现问题 → 写报告 → 开发者阅读报告 → 开发者修复 → 设计师验证
  （3-5天，高沟通成本，信息损耗大）

/design-review：
  AI 发现问题 → AI 修源码 → AI 提交 → AI 验证（before/after 截图）
  （30-60分钟，完整的审计+修复+证据链）
```

**五大独特价值**：
1. **AI Slop 检测**：大多数开发者自己检测不出来，AI 能系统性检测
2. **原子提交修复**：每个发现都有对应的可回滚 git commit
3. **before/after 截图证据**：不是"我修了"，而是"看，这是修前修后"
4. **设计系统提取**：从实际渲染的 DOM 提取设计系统，发现执行偏差
5. **量化设计分数（A-F）**：让"设计好不好"这个主观问题变得可追踪、可比较

---

## 完整技能触发条件总结

```
用户说...                           → /design-review 建议触发
─────────────────────────────────────────────────────────────
"check if it looks good"            → 强触发
"visual QA"                         → 强触发
"audit the design"                  → 强触发
"design polish"                     → 强触发
"does this look right?"             → 主动建议
"the spacing seems off"             → 主动建议
"it looks a bit generic"            → 主动建议
feature 分支 + UI 改动 pre-ship     → 主动建议

注意：如果在规划阶段（还没实现），用 /plan-design-review 而不是 /design-review
```

---

## v0.17.0.0 新增：UX 行为基础（`{{UX_PRINCIPLES}}`）

v0.17.0.0 将 UX 行为原则作为共享模板块注入到 `/design-review`。这些原则在"Prior Learnings"之后、审计阶段之前出现，作为评审的行为框架。

详细解读参见 [design-html.md 的 UX 原则章节](./design-html.md#v0170新增ux-原则用户实际行为ux_principles)。

### 在 `/design-review` 中的具体应用

UX 原则在 `/design-review` 中被用于两个关键位置：

**1. Phase 1（第一印象）中的"Page Area Test"**

> **原文**：Point at each clearly defined area of the page. Can you instantly name its purpose? ("Things I can buy," "Today's deals," "How to search.") Areas you can't name in 2 seconds are poorly defined.

这直接实现了 Billboard Design 原则——用户能否在 2 秒内理解每个区域的目的。如果 AI 也说不清，用户更说不清。

**2. Phase 3（逐页审计）中的"Trunk Test"**

每个页面都运行 Trunk Test，检验导航是否能回答 6 个问题：这是什么网站？我在哪个页面？主要版块是什么？等。Trunk Test FAIL 直接触发 HIGH impact 发现，即使页面其他方面都很漂亮。

**3. Phase 4（交互流程）中的"Goodwill Reservoir"**

审计时维护一个善意计量表（从 70/100 开始），每个摩擦点扣分，每个亮点加分。最终报告包含：

```
Goodwill: 35 ████████░░░░░░░░░░░░░░░░░░░░░░
  Step 1: Login page        70 → 75  (+5 obvious primary action)
  Step 2: Dashboard         75 → 60  (-15 interstitial tour popup)
  FINAL: 35/100 ⚠️ CRITICAL UX DEBT
```

这把"用户体验如何"从主观感受变成了可量化的 35/100。

**设计原理：为什么审计工具需要用户行为理论？**

传统的设计审计工具（Lighthouse、axe 等）只检查技术合规性（可访问性分数、对比度比例）。`/design-review` 的独特性在于：它用 UX 行为理论来判断设计是否真正服务于用户的实际行为模式。技术合规不等于用户友好——一个页面可以 WCAG 100 分但仍然让用户无法完成任务。
