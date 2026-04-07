# `/design-html` 技能逐段中英对照注解

> 对应源文件：[`design-html/SKILL.md`](https://github.com/garrytan/gstack/blob/main/design-html/SKILL.md)（1180 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: design-html
preamble-tier: 2
version: 1.0.0
description: |
  Design finalization: generates production-quality Pretext-native HTML/CSS.
  Works with approved mockups from /design-shotgun, CEO plans from /plan-ceo-review,
  design review context from /plan-design-review, or from scratch with a user
  description. Text actually reflows, heights are computed, layouts are dynamic.
  30KB overhead, zero deps. Smart API routing: picks the right Pretext patterns
  for each design type. Use when: "finalize this design", "turn this into HTML",
  "build me a page", "implement this design", or after any planning skill.
  Proactively suggest when user has approved a design or has a plan ready. (gstack)
  Voice triggers (speech-to-text aliases): "build the design", "code the mockup", "make it real".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---
```

**中文翻译与解读**：

- **name: design-html**：技能名称。用户输入 `/design-html` 触发，或语音说 "build the design" / "code the mockup" / "make it real"。
- **preamble-tier: 2**：Preamble 详细度 Tier 2。包含 Bash 环境初始化、会话追踪、遥测、Learnings 加载，但不包含 Tier 3/4 的完整 repo 模式检测。足够用于设计生成，不需要扫描整个 codebase。
- **description** 的关键承诺：**"Text actually reflows, heights are computed, layouts are dynamic."** 这是与普通 AI 生成 HTML 的根本区别——用 Pretext 引擎做真实布局计算，不是 CSS 近似。
- **30KB overhead, zero deps**：整个 Pretext 引擎只有 30KB，而且不依赖任何外部包。生产级使用完全可接受。
- **Smart API routing**：设计类型不同，使用的 Pretext API 不同。landing page 用 `prepare()+layout()`，聊天 UI 用 `prepareWithSegments()+walkLineRanges()`。这个智能路由让 AI 自动选择正确模式。
- **allowed-tools 包含 Edit 和 Agent**：这与 `/plan-eng-review` 不同。design-html 是执行技能，不是评审技能。它**确实会写文件**——HTML、DESIGN.md、finalized.json。`Agent` 工具用于框架检测和组件输出（但主要工作是串行的）。

> **设计原理：为什么有 Edit 而不只有 Write？**
> 精化循环（refinement loop）是外科手术式编辑，不是整体重写。用户可能在 `contenteditable` 里改了内容，如果用 Write 整体覆盖会丢失这些编辑。Edit 工具保证增量修改。

---

## 技能定位：从方案到生产级 HTML

### 在 gstack 设计流水线中的位置

```
用户有想法
    │
    ▼
/office-hours ──→ 产品定义文档 (.md)
    │
    ▼
/plan-ceo-review ──→ CEO 方案文件 (~/.gstack/projects/$SLUG/ceo-plans/)
    │
    ▼
/plan-design-review ──→ 设计规格（视觉风格、间距、颜色约束）
    │
    ▼
/design-shotgun ──→ 多个视觉方向 PNG + approved.json
    │
    ▼
[**你在这里**] /design-html ──→ 生产级 HTML/CSS + finalized.html
    │
    ▼
/ship ──→ 提交、推送、PR
```

**design-html 是流水线的最后一公里**。它把所有上游的思考（产品方案、设计探索、批准的视觉方向）转化为可以直接放进 repo 的代码。

### 四种输入模式对比

| 模式 | 触发条件 | 视觉参考 | 内容来源 |
|------|---------|---------|---------|
| **approved-mockup** | `approved.json` 存在 | `/design-shotgun` 生成的 PNG | 从 mockup 提取 |
| **plan-driven** | 有 CEO plan，但无 approved.json | 无图片 | CEO plan 文档 |
| **freeform** | 什么都没有 | 无图片 | 用户实时描述 |
| **evolve** | `finalized.html` 已存在 | 现有 HTML 文件 | 用户反馈 + 原始文件 |

> **为什么有这四种模式？**
> 现实中用户不总是走完整流水线。有时候直接说"帮我做个 landing page"，这时候 freeform 模式直接开始；有时候方案做好了但不需要 shotgun 阶段，这时 plan-driven 可以直接下手；有时候需要迭代已有页面，这时 evolve 模式最合适。四种模式覆盖了所有实际使用场景。

---

## Pretext 框架介绍

### 什么是 Pretext？

> **原文**：
> ```
> You generate production-quality HTML where text actually works correctly. Not CSS
> approximations. Computed layout via Pretext. Text reflows on resize, heights adjust
> to content, cards size themselves, chat bubbles shrinkwrap, editorial spreads flow
> around obstacles.
> ```

**中文**：你生成文本真正正确工作的生产级 HTML。不是 CSS 近似——通过 Pretext 做计算布局。文本在 resize 时回流，高度自动适应内容，卡片自我调整尺寸，聊天气泡缩紧贴合，编辑排版绕障碍物流动。

### CSS 近似 vs Pretext 计算布局

CSS 处理文本布局的方式从根本上就是"近似的"：

```
CSS 的问题（近似）：
┌─────────────────────────────┐
│  height: auto  ──────────?  │  CSS 不知道文本实际多高
│  overflow: hidden  ──────?  │  截断还是显示？不确定
│  line-height: 1.5  ──────?  │  跨字体不一致
│  white-space: nowrap  ───?  │  固定宽度里会溢出
└─────────────────────────────┘

Pretext 的方式（计算）：
┌─────────────────────────────┐
│  prepare(text, font)        │  测量文字
│  ──→ handle                 │  一次性工作
│                             │
│  layout(handle, width, lh)  │  实际计算
│  ──→ { height, lineCount }  │  精确结果
└─────────────────────────────┘
```

**Pretext 的核心理念**：把"文本测量"（昂贵，做一次）和"布局计算"（廉价，每次 resize 都做）分离。

### Pretext API 全景

```
PRETEXT API 速查表：

prepare(text, font) → handle
  一次性文本测量。在 document.fonts.ready 之后调用。
  Font: CSS 简写，如 '16px Inter' 或 'bold 24px Georgia'。

layout(prepared, maxWidth, lineHeight) → { height, lineCount }
  快速布局计算。每次 resize 都调用。亚毫秒级。

prepareWithSegments(text, font) → handle
  类似 prepare()，但启用下面的行级 API。

layoutWithLines(segs, maxWidth, lineHeight) → { lines: [{text, width, x, y}...], height }
  完整的逐行分解。用于 Canvas/SVG 渲染。

walkLineRanges(segs, maxWidth, onLine) → void
  对每种可能的布局调用 onLine(lineCount, startIdx, endIdx)。
  找到 N 行所需的最小宽度。用于紧凑容器。

layoutNextLine(segs, state, maxWidth, lineHeight) → { text, width, state } | null
  迭代器。每行用不同的 maxWidth = 文本绕障碍物。
  初始 state 传 null。文本用完时返回 null。

clearCache() → void
  清除内部测量缓存。在循环多种字体时使用。

setLocale(locale?) → void
  为之后的 prepare() 调用重定向词语分割器。
```

### 30KB、零依赖意味着什么？

| 属性 | 数值 | 含义 |
|------|------|------|
| 包大小 | ~30KB gzip | 比一张 JPG 还小 |
| 依赖数量 | 0 | 不需要 npm install |
| 运行环境 | 纯浏览器 JS | 无 Node.js、无构建工具 |
| CDN URL | `https://esm.sh/@chenglou/pretext` | 或 vendor 内联 |

> **设计原理**：零依赖不只是哲学。如果你要把生成的 HTML 放进各种项目，没有依赖意味着它永远不会有"某个 npm 包坏了"的问题。Pretext 做的事情（文本测量）在浏览器里本来就可以做，只是之前没人封装成好用的 API。

---

## 环境初始化：DESIGN SETUP

### 原文（第 549-604 行）

```bash
# Step 1：检测 $D（设计二进制）
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
D=""
[ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/design/dist/design" ] && D="$_ROOT/.claude/skills/gstack/design/dist/design"
[ -z "$D" ] && D=~/.claude/skills/gstack/design/dist/design
if [ -x "$D" ]; then
  echo "DESIGN_READY: $D"
else
  echo "DESIGN_NOT_AVAILABLE"
fi

# Step 2：检测 $B（浏览器二进制）
B=""
[ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="$_ROOT/.claude/skills/gstack/browse/dist/browse"
[ -z "$B" ] && B=~/.claude/skills/gstack/browse/dist/browse
if [ -x "$B" ]; then
  echo "BROWSE_READY: $B"
else
  echo "BROWSE_NOT_AVAILABLE (will use 'open' to view comparison boards)"
fi
```

**中文解读**：

这段 bash 做了两件事：检测 `$D`（设计生成二进制）和 `$B`（无头浏览器二进制）。两个都是可选的——技能做了优雅降级设计：

```
检测结果 → 行为
─────────────────────────────────────────────────────
DESIGN_READY     → 使用 $D 分析 mockup PNG、提取实现规格
DESIGN_NOT_AVAIL → 跳过视觉分析，改为 AI 直接阅读 PNG 描述布局

BROWSE_READY     → 用 $B 截图验证三个视口（375/768/1440px）
BROWSE_NOT_AVAIL → 用 'open file://...' 在系统浏览器中打开
```

> **设计原理**：Progressive Enhancement 思想。核心功能（生成 HTML）不依赖任何额外工具。设计二进制和浏览器二进制只是加速和验证。即使全不可用，技能也能完成任务。

### $D 命令对照表

```
$D generate --brief "..." --output /path.png
  → 生成单个 mockup 图片

$D variants --brief "..." --count 3 --output-dir /path/
  → 并行生成 N 个风格变体

$D compare --images "a.png,b.png,c.png" --output /path/board.html --serve
  → 生成比较板 HTML + 启动 HTTP 服务器

$D serve --html /path/board.html
  → 单独启动比较板服务器

$D check --image /path.png --brief "..."
  → 视觉质量门（用 GPT-4o vision 验证是否符合 brief）

$D iterate --session /path/session.json --feedback "..." --output /path.png
  → 基于反馈迭代

$D prompt --image <approved-variant.png> --output json
  → 从图片提取颜色、排版、布局结构（用于 Step 1 设计分析）

$D evolve --screenshot current.png --brief "..." --output variant.png
  → 从截图生成改进变体（用于"我不喜欢现有设计"场景）
```

---

## 重要设计规则：设计产物存储路径

> **原文**：
> ```
> CRITICAL PATH RULE: All design artifacts (mockups, comparison boards, approved.json)
> MUST be saved to `~/.gstack/projects/$SLUG/designs/`, NEVER to `.context/`,
> `docs/designs/`, `/tmp/`, or any project-local directory. Design artifacts are USER
> data, not project files. They persist across branches, conversations, and workspaces.
> ```

**中文**：所有设计产物（mockup、比较板、approved.json）**必须**保存到 `~/.gstack/projects/$SLUG/designs/`，**绝对不能**保存到 `.context/`、`docs/designs/`、`/tmp/` 或任何项目本地目录。设计产物是**用户数据**，不是项目文件。它们跨分支、跨对话、跨工作区持久存在。

> **设计原理**：这个规则反映了一个深层设计理念——**设计探索属于用户，不属于项目**。如果你把 mockup 存在 repo 里，切换分支就找不到了。如果存在 `/tmp/`，重启就没了。存在 `~/.gstack/` 里，无论你在哪个分支工作、在哪台机器（同步后）都能找到。

---

## Step 0：输入检测与路由

### 四重检查

```bash
# 检查 1：有没有 CEO 方案（/plan-ceo-review 的产物）
_CEO=$(ls -t ~/.gstack/projects/$SLUG/ceo-plans/*.md 2>/dev/null | head -1)

# 检查 2：有没有批准的 mockup（/design-shotgun 的产物）
_APPROVED=$(ls -t ~/.gstack/projects/$SLUG/designs/*/approved.json 2>/dev/null | head -1)

# 检查 3：有没有设计变体 PNG（design-shotgun 中间产物）
_VARIANTS=$(ls -t ~/.gstack/projects/$SLUG/designs/*/variant-*.png 2>/dev/null | head -1)

# 检查 4：有没有已经生成的 finalized.html + DESIGN.md
_FINALIZED=$(ls -t ~/.gstack/projects/$SLUG/designs/*/finalized.html 2>/dev/null | head -1)
[ -f DESIGN.md ] && echo "DESIGN_MD: exists"
```

### 路由决策树

```
Step 0 检测结果
      │
      ├─ APPROVED 存在？
      │      │
      │      YES → Case A（approved-mockup 模式）
      │             ├─ 同时有 FINALIZED？
      │             │      YES → AskUser: 进化还是重新生成？
      │             │      NO  → 直接进入 Step 1
      │             └─ 读取 approved.json，提取变体路径 + 反馈 + 屏幕名
      │
      ├─ CEO_PLAN 或 VARIANTS 存在，但无 APPROVED？
      │      │
      │      YES → Case B（有上下文但未批准）
      │             └─ AskUser: A) 先跑 /design-shotgun
      │                         B) 直接从 plan 生成 HTML
      │                         C) 我有 PNG，给你路径
      │
      └─ 什么都没有？
             │
             YES → Case C（白板模式）
                    └─ AskUser: A) 先跑 /plan-ceo-review
                                B) 先跑 /plan-design-review
                                C) 先跑 /design-shotgun
                                D) 直接描述，我现在生成
```

> **设计原理：为什么不直接问用户要什么？**
> 技能先检查文件系统，是因为用户可能**忘了**他们已经有了 CEO plan 或 approved mockup。主动发现上下文比被动等待提供更好——减少用户认知负担。

### Context Summary（上下文摘要）

路由完成后，技能输出一个简洁摘要：

```
- Mode: approved-mockup
- Visual reference: ~/.gstack/projects/my-app/designs/landing-20240115/variant-A.png
- CEO plan: ~/.gstack/projects/my-app/ceo-plans/2024-01-14.md
- Design tokens: DESIGN.md
- Screen name: landing-page
```

这个摘要告诉用户技能"看到了什么"，防止误解。

---

## Step 1：设计分析

### 原文（第 730-757 行）

> ```
> 1. If $D is available (DESIGN_READY), extract a structured implementation spec:
>    $D prompt --image <approved-variant.png> --output json
>    This returns colors, typography, layout structure, and component inventory via GPT-4o vision.
>
> 2. If $D is not available, read the approved PNG inline using the Read tool.
>    Describe the visual layout, colors, typography, and component structure yourself.
>
> 3. If in plan-driven or freeform mode (no approved PNG), design from context...
>
> 4. Read DESIGN.md tokens. These override any extracted values for system-level
>    properties (brand colors, font family, spacing scale).
>
> 5. Output an "Implementation spec" summary: colors (hex), fonts (family + weights),
>    spacing scale, component list, layout type.
> ```

**中文**：

Step 1 的目标是生成一份**实现规格（Implementation Spec）**，作为 Step 3 写代码的依据：

```
实现规格内容：
  colors:
    primary: #1a1a2e
    secondary: #16213e
    accent: #0f3460
    text: #e94560
  fonts:
    heading: "Playfair Display", serif, weights: [700, 900]
    body: "Inter", sans-serif, weights: [400, 500]
  spacing:
    unit: 8px
    scale: [4, 8, 16, 24, 32, 48, 64, 96]
  components:
    - hero-section (full-width, 100vh)
    - feature-grid (3-column, card-based)
    - testimonial-strip (horizontal scroll)
    - pricing-table (3-tier)
  layout: marketing-page
```

**DESIGN.md 的优先级问题**：

```
优先级（高 → 低）：
┌─────────────────────────────────────┐
│ DESIGN.md tokens（最高优先级）       │  ← 项目级品牌约束
│ $D prompt 从 PNG 提取的值            │  ← 视觉参考
│ AI 自己推断的默认值                  │  ← 最后兜底
└─────────────────────────────────────┘
```

这个优先级设计很关键：如果你的 DESIGN.md 里指定了 `primary: #FF5733`，但 approved mockup 里用的是 `#FF0000`，结果会用 DESIGN.md 的值。品牌一致性高于单次设计。

---

## Step 2：Smart API Routing（智能 API 路由）

### 路由表（原文第 766-773 行）

> ```
> | Design type                          | Pretext APIs                          | Use case                      |
> |--------------------------------------|---------------------------------------|-------------------------------|
> | Simple layout (landing, marketing)   | prepare() + layout()                  | Resize-aware heights          |
> | Card/grid (dashboard, listing)       | prepare() + layout()                  | Self-sizing cards             |
> | Chat/messaging UI                    | prepareWithSegments() + walkLineRanges()| Tight-fit bubbles, min-width |
> | Content-heavy (editorial, blog)      | prepareWithSegments() + layoutNextLine()| Text around obstacles        |
> | Complex editorial                    | Full engine + layoutWithLines()       | Manual line rendering         |
> ```

**中文解读**：这是 design-html 技能最有技术深度的部分。不同的设计类型需要不同的 Pretext 能力：

```
设计类型 → API 选择 → 原因

Landing page：
  prepare() + layout()
  ──→ 只需要知道"这段文字有多高"
  ──→ 每次 resize 重算一下
  ──→ 最简单，最快

聊天气泡：
  prepareWithSegments() + walkLineRanges()
  ──→ 需要找"最紧凑的宽度"
  ──→ walkLineRanges 遍历所有可能的布局
  ──→ 找到不增加行数的最窄宽度
  ──→ 气泡宽度 = 内容宽度，不是固定宽度

文章绕图：
  prepareWithSegments() + layoutNextLine()
  ──→ 每一行的可用宽度不同（图片占了一部分）
  ──→ layoutNextLine 支持"这一行最大 300px，下一行最大 500px"
  ──→ 文字自然绕着图片流动

复杂排版（Canvas/SVG）：
  prepareWithSegments() + layoutWithLines()
  ──→ 需要知道每一行的精确位置（x, y, width）
  ──→ 用于 Canvas 渲染、SVG 排版
  ──→ 最强大但最复杂
```

> **为什么叫"Smart"Routing？**
> 因为 AI 会根据设计内容**自动判断**用哪个 tier，不需要用户指定。一个人看到"这是聊天 UI"会选 `walkLineRanges`，AI 也会。这节省了用户学习 Pretext API 的成本。

### API 选择流程图

```
                        分析设计类型
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
    普通布局              聊天/消息              内容密集
  (landing/marketing)   (chat bubble)        (editorial/blog)
         │                    │                    │
  prepare()+layout()   prepareWithSegs()   prepareWithSegs()
                       +walkLineRanges()   +layoutNextLine()
                                                    │
                                                    └─ 需要 Canvas/SVG？
                                                         YES → +layoutWithLines()
```

---

## Step 2.5：框架检测

### 原文（第 779-797 行）

> ```bash
> [ -f package.json ] && cat package.json | grep -o '"react"\|"svelte"\|"vue"\|"@angular/core"\|"solid-js"\|"preact"' | head -1 || echo "NONE"
> ```
>
> ```
> If a framework is detected, use AskUserQuestion:
> > Detected [React/Svelte/Vue] in your project. What format should the output be?
> > A) Vanilla HTML — self-contained preview file (recommended for first pass)
> > B) [React/Svelte/Vue] component — framework-native with Pretext hooks
> ```

**中文**：检测到框架后，AI 会问用户想要 vanilla HTML 还是框架组件。

| 选项 | 输出格式 | 适合场景 |
|------|---------|---------|
| Vanilla HTML | `finalized.html`（自含式） | 第一次预览、快速迭代 |
| React 组件 | `finalized.tsx` / `finalized.jsx` | 已有 React 项目，直接集成 |
| Svelte 组件 | `finalized.svelte` | 已有 Svelte 项目 |
| Vue 组件 | `finalized.vue` | 已有 Vue 项目 |

**框架输出时的 Pretext 安装**：

```bash
# 自动检测包管理器
[ -f bun.lockb ]        && echo "bun add @chenglou/pretext"
[ -f pnpm-lock.yaml ]   && echo "pnpm add @chenglou/pretext"
[ -f yarn.lock ]        && echo "yarn add @chenglou/pretext"
# 默认
echo "npm install @chenglou/pretext"
```

---

## Step 3：生成 Pretext 原生 HTML

### Pretext 源码内联策略

> **原文**：
> ```bash
> _PRETEXT_VENDOR=""
> _ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
> [ -n "$_ROOT" ] && [ -f "$_ROOT/.claude/skills/gstack/design-html/vendor/pretext.js" ] && ...
> [ -z "$_PRETEXT_VENDOR" ] && [ -f ~/.claude/skills/gstack/design-html/vendor/pretext.js ] && ...
> ```
>
> - If `VENDOR` found: read the file and inline it in a `<script>` tag. The HTML file
>   is fully self-contained with zero network dependencies.
> - If `VENDOR_MISSING`: use CDN import as fallback

**中文**：技能尝试把 Pretext 的代码**内联**到生成的 HTML 文件里，使其完全自含：

```
查找 vendor/pretext.js
      │
  找到了？
      │
  YES ─────→ 读取文件内容，内联到 <script> 标签
             <script>/* pretext.js 全部内容 */</script>
             → 文件完全自含，无网络依赖，任何地方都能打开
      │
  NO  ─────→ 使用 CDN fallback
             <script type="module">
               import { prepare, layout } from 'https://esm.sh/@chenglou/pretext'
             </script>
             → 需要网络，加 <!-- FALLBACK: vendor/pretext.js missing, using CDN -->
```

> **设计原理**：自含式 HTML 的价值在于，你可以把这个文件发给设计师、PM、投资人，他们双击就能看，不需要 npm install、不需要启动服务器、不需要 node。这是"可以被邮件发送的 UI 原型"。

### HTML 生成规则：必须包含

> **原文**（第 838-851 行）：
> ```
> Always include in vanilla HTML:
> - Pretext source (inlined or CDN)
> - CSS custom properties for design tokens from DESIGN.md / Step 1 extraction
> - Google Fonts via <link> tags + document.fonts.ready gate before first prepare()
> - Semantic HTML5 (<header>, <nav>, <main>, <section>, <footer>)
> - Responsive behavior via Pretext relayout (not just media queries)
> - Breakpoint-specific adjustments at 375px, 768px, 1024px, 1440px
> - ARIA attributes, heading hierarchy, focus-visible states
> - contenteditable on text elements + MutationObserver to re-prepare + re-layout on edit
> - ResizeObserver on containers to re-layout on resize
> - prefers-color-scheme media query for dark mode
> - prefers-reduced-motion for animation respect
> - Real content extracted from the mockup (never lorem ipsum)
> ```

**中文解读**：这 12 条规则不是可选的，是**强制性标准**。

| 规则 | 中文 | 为什么强制？ |
|------|------|------------|
| Pretext source | Pretext 源码 | 核心功能 |
| CSS custom properties | CSS 变量（设计 token） | 方便后续修改、维护一致性 |
| Google Fonts + fonts.ready | 字体 + 字体加载门控 | 必须在字体加载完后才能准确测量 |
| Semantic HTML5 | 语义化 HTML | SEO、可访问性、可维护性 |
| Responsive via Pretext | 用 Pretext 做响应式 | 媒体查询只能改 CSS，Pretext 重算真实高度 |
| Breakpoints: 375/768/1024/1440px | 四个标准断点 | 覆盖手机/平板/桌面/大屏 |
| ARIA + focus-visible | 无障碍 | 基本的可访问性要求 |
| contenteditable + MutationObserver | 实时编辑 + 重排 | 让 HTML 本身可以作为设计工具 |
| ResizeObserver | 容器大小监听 | 窗口缩放时重新计算布局 |
| prefers-color-scheme | 暗色模式 | 现代标准 |
| prefers-reduced-motion | 减少动画 | 无障碍 |
| Real content | 真实内容 | Lorem ipsum 是"假设内容的代码"，不是真实设计 |

### HTML 生成规则：AI 黑名单

> **原文**（第 852-863 行）：
> ```
> Never include (AI slop blacklist):
> - Purple/blue gradients as default
> - Generic 3-column feature grids
> - Center-everything layouts with no visual hierarchy
> - Decorative blobs, waves, or geometric patterns not in the mockup
> - Stock photo placeholder divs
> - "Get Started" / "Learn More" generic CTAs not from the mockup
> - Rounded-corner cards with drop shadows as the default component
> - Emoji as visual elements
> - Generic testimonial sections
> - Cookie-cutter hero sections with left-text right-image
> ```

**中文**：AI 生成 HTML 的常见"脏操作"黑名单——这些是 AI 在没有足够上下文时的**默认输出模式**，看起来像是做了很多，但其实是模板堆砌。

```
AI 设计"懒人黑名单"（禁止）：

❌ 紫色/蓝色渐变作为默认
   → 几乎所有 AI 生成 UI 都这样，毫无区分度

❌ 通用三列 feature grid
   → "图标 + 标题 + 描述 × 3"，没有设计思考

❌ 全部居中、无视觉层次
   → 居中不等于设计，只是放弃了设计决策

❌ 装饰性 blob/wave/几何图案（mockup 里没有的）
   → AI 觉得"加点装饰就好看了"，但这是噪声

❌ 占位图 div
   → <div class="hero-image">Image placeholder</div> 毫无价值

❌ "Get Started" / "Learn More" 通用 CTA
   → 如果 mockup 里没有，不要自己加

❌ 圆角卡片 + 阴影作为默认组件
   → Notion、Linear 流行了之后，所有 AI 都这样做

❌ Emoji 作为视觉元素
   → 👋🚀✨ 不是设计

❌ 通用 testimonial section
   → 随机生成的假评价，只是填充空间

❌ 左文右图的 hero
   → 1990 年代的 brochure 网站风格，不是现代设计
```

> **这份黑名单揭示了一个深层问题**：AI 的"默认风格"是所有它见过的 UI 的平均值。平均值永远是平庸的。真正的设计需要**来自 mockup 或具体需求的约束**才能避开这些陷阱。

---

## Step 3 Pretext 接线模式详解

### 模式 1：基础高度计算（Landing page / 卡片）

```javascript
import { prepare, layout } from './pretext-inline.js'
// 或如果已内联：const { prepare, layout } = window.Pretext

// 1. PREPARE — 一次性，字体加载后执行
await document.fonts.ready
const elements = document.querySelectorAll('[data-pretext]')
const prepared = new Map()

for (const el of elements) {
  const text = el.textContent
  const font = getComputedStyle(el).font
  prepared.set(el, prepare(text, font))
}

// 2. LAYOUT — 廉价，每次 resize 都调用
function relayout() {
  for (const [el, handle] of prepared) {
    const { height } = layout(handle, el.clientWidth, parseFloat(getComputedStyle(el).lineHeight))
    el.style.height = `${height}px`
  }
}

// 3. 响应式
new ResizeObserver(() => relayout()).observe(document.body)
relayout()

// 4. contenteditable — 文本变化时重新 prepare + layout
for (const el of elements) {
  if (el.contentEditable === 'true') {
    new MutationObserver(() => {
      const font = getComputedStyle(el).font
      prepared.set(el, prepare(el.textContent, font))
      relayout()
    }).observe(el, { characterData: true, subtree: true, childList: true })
  }
}
```

**关键点**：
- `document.fonts.ready` 是字体加载门控——必须等字体加载完，测量才准确
- `prepare()` 只调用一次（字体相同、文本不变时），`layout()` 每次 resize 都调
- MutationObserver 让 `contenteditable` 元素在用户编辑时实时重排

### 模式 2：收缩贴合（聊天气泡）

```javascript
// 找到产生相同行数的最紧凑宽度
function shrinkwrap(text, font, maxWidth, lineHeight) {
  const { lineCount: targetLines } = layout(prepare(text, font), maxWidth, lineHeight)
  let lo = 0, hi = maxWidth
  // 二分搜索：找到不增加行数的最窄宽度
  while (hi - lo > 1) {
    const mid = (lo + hi) / 2
    const { lineCount } = layout(prepare(text, font), mid, lineHeight)
    if (lineCount === targetLines) hi = mid
    else lo = mid
  }
  return hi  // 最紧凑的宽度
}
```

**效果**：聊天气泡的宽度 = 内容的实际宽度，不会因为容器宽度而变宽。

### 模式 3：文字绕障碍物（文章排版）

```javascript
function layoutAroundObstacles(text, font, containerWidth, lineHeight, obstacles) {
  const segs = prepareWithSegments(text, font)
  let state = null
  let y = 0
  const lines = []

  while (true) {
    // 计算当前 y 位置的可用宽度（减去障碍物占的空间）
    let availWidth = containerWidth
    for (const obs of obstacles) {
      if (y >= obs.top && y < obs.top + obs.height) {
        availWidth -= obs.width  // 障碍物在这一行，减去它的宽度
      }
    }

    const result = layoutNextLine(segs, state, availWidth, lineHeight)
    if (!result) break  // 文字排完了

    lines.push({ text: result.text, width: result.width, x: 0, y })
    state = result.state
    y += lineHeight
  }

  return { lines, totalHeight: y }
}
```

**效果**：文章里的图片旁边，文字会自然绕着图片排列，而不是截断或溢出。

### 模式 4：逐行渲染（Canvas/SVG）

```javascript
const segs = prepareWithSegments(text, font)
const { lines, height } = layoutWithLines(segs, containerWidth, lineHeight)

// lines = [{ text, width, x, y }, ...]
for (const line of lines) {
  const span = document.createElement('span')
  span.textContent = line.text
  span.style.position = 'absolute'
  span.style.left = `${line.x}px`
  span.style.top = `${line.y}px`
  container.appendChild(span)
}
```

**效果**：完全手动控制每行文字的位置，可以做 Canvas 渲染、SVG 文字、自定义动画。

---

## Step 3.5：实时预览服务器

> **原文**（第 1020-1046 行）：
> ```bash
> _OUTPUT_DIR=$(dirname <path-to-finalized.html>)
> cd "$_OUTPUT_DIR"
> python3 -m http.server 0 --bind 127.0.0.1 &
> _SERVER_PID=$!
> _PORT=$(lsof -i -P -n | grep "$_SERVER_PID" | grep LISTEN | awk '{print $9}' | cut -d: -f2 | head -1)
> echo "SERVER: http://localhost:$_PORT/finalized.html"
> ```

**中文**：生成 HTML 后立即启动一个本地 HTTP 服务器，让用户可以在浏览器里实时看效果。

**为什么不直接 `open file://...`？**

```
file:// 协议 vs http:// 协议：

file://...
  - CORS 限制：ES Module import 会失败
  - 字体加载：某些情况下受限
  - 绝对路径：移动文件后失效

http://localhost:PORT/...
  - CORS 正常：所有 JS 功能可用
  - 字体加载：完全正常
  - 相对路径：正常工作
```

> 用 `python3 -m http.server 0` 的 `0` 端口让 OS 自动分配端口，避免端口冲突。

---

## Step 4：预览 + 精化循环

### 三视口验证截图

> **原文**（第 1054-1068 行）：
> ```bash
> $B goto "file://<path-to-finalized.html>"
> $B screenshot /tmp/gstack-verify-mobile.png --width 375
> $B screenshot /tmp/gstack-verify-tablet.png --width 768
> $B screenshot /tmp/gstack-verify-desktop.png --width 1440
> ```
> Check for:
> - Text overflow (text cut off or extending beyond containers)
> - Layout collapse (elements overlapping or missing)
> - Responsive breakage (content not adapting to viewport)

**中文**：如果浏览器二进制 `$B` 可用，在提交给用户之前先做**自动视口验证**——375px（手机）、768px（平板）、1440px（桌面）三个截图，让 AI 自己检查常见问题。

```
自动检查清单：
□ 文字溢出（文字被截断或超出容器）
□ 布局崩溃（元素重叠或消失）
□ 响应式失效（内容不适应视口）
```

### 精化循环逻辑

```
LOOP（最多 10 次）：
  1. 告诉用户打开 http://localhost:PORT/finalized.html
  
  2. 如果有 approved mockup PNG，并排展示它
     （让用户可以对比"目标"和"实现"）
  
  3. AskUserQuestion（根据模式调整措辞）：
     有 mockup：
       "HTML 已在浏览器里。这是批准的 mockup 供对比。
        试试：缩放窗口（文字动态回流），
        点击文字（可编辑，布局即时重算）。
        需要改什么？满意了说 'done'。"
     
     无 mockup：
       "HTML 已在浏览器里。试试：缩放窗口，点击文字。
        需要改什么？满意了说 'done'。"
  
  4. 如果用户说 "done" / "ship it" / "looks good" / "perfect"
     → 退出循环，进入 Step 5
  
  5. 根据反馈，用 Edit 工具做**外科手术式修改**（不要重写整个文件！）
  
  6. 简短摘要（2-3 行）说明改了什么
  
  7. 如果有 $B，重新截图确认修复
  
  8. 回到 LOOP
```

**外科手术式修改 vs 整体重写**：

```
用户说："把标题改成蓝色"

✅ 正确做法（Edit 工具）：
   找到 .hero h1 { color: ... }，改成 color: #0066cc

❌ 错误做法（Write 工具）：
   重新生成整个 1000 行 HTML 文件
   → 用户之前通过 contenteditable 做的改动全部丢失
```

---

## Step 5：保存 & 后续步骤

### 设计 Token 提取

> **原文**（第 1112-1130 行）：
> ```
> If no DESIGN.md exists in the repo root, offer to create one from the generated HTML:
> Extract from the HTML:
> - CSS custom properties (colors, spacing, font sizes)
> - Font families and weights used
> - Color palette (primary, secondary, accent, neutral)
> - Spacing scale
> - Border radius values
> - Shadow values
> ```

**中文**：如果项目还没有 DESIGN.md，AI 会从刚生成的 HTML 里提取设计 token，**反向创建 DESIGN.md**。

这是一个有意思的循环：
1. 第一次运行 design-html：没有 DESIGN.md，从 mockup 或描述生成 HTML
2. AI 从 HTML 提取 token，生成 DESIGN.md
3. 第二次运行 design-html：有了 DESIGN.md，新生成的 HTML 会自动遵守设计系统

这样，设计系统是**从实际代码里生长出来的**，而不是凭空制定的。

### finalized.json 元数据

```json
{
  "source_mockup": "~/.gstack/projects/my-app/designs/landing-20240115/variant-A.png",
  "source_plan": "~/.gstack/projects/my-app/ceo-plans/2024-01-14.md",
  "mode": "approved-mockup",
  "html_file": "~/.gstack/projects/my-app/designs/landing-20240115/finalized.html",
  "pretext_tier": "simple-layout",
  "framework": "vanilla",
  "iterations": 3,
  "date": "2024-01-15T10:30:00Z",
  "screen": "landing-page",
  "branch": "feature/new-landing"
}
```

---

## 重要规则解析

### 规则 1：忠实度优于代码优雅

> **原文**：
> ```
> Source of truth fidelity over code elegance. When an approved mockup exists,
> pixel-match it. If that requires `width: 312px` instead of a CSS grid class, that's
> correct. When in plan-driven or freeform mode, the user's feedback during the
> refinement loop is the source of truth. Code cleanup happens later during
> component extraction.
> ```

**中文**：如果批准的 mockup 要求 `width: 312px`，就写 `width: 312px`，不要因为"这不是好的 CSS 写法"就改成 `width: 50%` 或用 grid。**现在的目标是像素级还原，不是写教科书级的 CSS**。代码清理是后面的事。

### 规则 2：永远用 Pretext 处理文本布局

> **原文**：
> ```
> Always use Pretext for text layout. Even if the design looks simple, Pretext
> ensures correct height computation on resize. The overhead is 30KB. Every page benefits.
> ```

**中文**：即使设计看起来简单，也要用 Pretext。30KB 的开销对每个页面都值得，因为你永远不会有"文字截断但我不知道"的问题。

### 规则 3：精化循环用 Edit，不用 Write

> **原文**：
> ```
> Surgical edits in the refinement loop. Use the Edit tool to make targeted changes,
> not the Write tool to regenerate the entire file. The user may have made manual edits
> via contenteditable that should be preserved.
> ```

**中文**：用户可能通过 `contenteditable` 直接在浏览器里改了内容。用 Write 整体重写会丢失这些修改。Edit 工具保证只改需要改的部分。

### 规则 4：真实内容，不用占位符

> **原文**：
> ```
> Real content only. When a mockup exists, extract text from it. In plan-driven mode,
> use content from the plan. In freeform mode, generate realistic content based on the
> user's description. Never use "Lorem ipsum", "Your text here", or placeholder content.
> ```

**中文**：Lorem ipsum 不是"中性的内容"——它是**内容缺失的可见标志**，会影响设计判断（"这里的间距够不够？不知道，内容是假的"）。真实内容才能做出真实的设计决策。

### 规则 5：每次调用只做一个页面

> **原文**：
> ```
> One page per invocation. For multi-page designs, run /design-html once per page.
> Each run produces one HTML file.
> ```

**中文**：每次 `/design-html` 只生成一个页面。多页面设计需要多次调用。这不是限制，是**合理的 scope 控制**——一个页面的细化就足够复杂了。

---

## 完整工作流总览

```
用户：/design-html
          │
          ▼
Preamble: 环境检测（$D, $B, sessions, telemetry）
          │
          ▼
Step 0: 输入检测
  ├─ Case A: approved.json → approved-mockup 模式
  ├─ Case B: CEO plan/variants → plan-driven 或询问
  └─ Case C: 空 → freeform 或引导到其他技能
          │
          ▼
Step 1: 设计分析
  ├─ $D prompt 提取 colors/fonts/layout（$D 可用时）
  ├─ AI 直接读 PNG 描述（$D 不可用时）
  └─ DESIGN.md tokens 覆盖（优先级最高）
  → 输出: Implementation Spec
          │
          ▼
Step 2: Smart API Routing
  └─ 根据设计类型选 Pretext tier
          │
          ▼
Step 2.5: Framework Detection
  └─ vanilla / React / Svelte / Vue？
          │
          ▼
Step 3: 生成 HTML
  ├─ Pretext 内联（优先）或 CDN fallback
  ├─ 按 12 条必须规则生成
  ├─ 避开黑名单 10 条
  └─ 保存到 ~/.gstack/projects/$SLUG/designs/xxx/finalized.html
          │
          ▼
Step 3.5: 启动预览服务器
  └─ python3 -m http.server 0
          │
          ▼
Step 4: 预览 + 精化循环（最多 10 次）
  ├─ $B 截图验证（375/768/1440px）
  ├─ AskUserQuestion（展示 mockup 对比）
  ├─ 用户反馈 → Edit 工具外科手术式修改
  └─ 直到用户说 "done"
          │
          ▼
Step 5: 保存 & 后续
  ├─ 没有 DESIGN.md？从 HTML 提取 tokens 创建
  ├─ 写 finalized.json 元数据
  └─ AskUserQuestion: 复制到项目 / 继续迭代 / 完成
          │
          ▼
Telemetry: 记录执行时间和结果
```

---

## 与 /design-shotgun 的配合关系

design-html 和 design-shotgun 是**两个不同阶段**的工具：

| 维度 | /design-shotgun | /design-html |
|------|----------------|-------------|
| **阶段** | 探索（发散） | 收敛（实现） |
| **产出** | PNG mockups + approved.json | finalized.html |
| **工具** | $D（AI 图片生成） | Pretext（计算布局） |
| **用户交互** | 比较选择 | 精化迭代 |
| **是否写代码** | 否 | 是 |
| **迭代速度** | 快（看图，60s/round） | 慢（改代码，需要看效果） |

**典型工作流**：

```
需求 → /design-shotgun → 选方向 → /design-html → 精化 → /ship
        （探索，生成图）           （实现，生成代码）
```

**直接跳过 shotgun**：
- 有明确方案（plan-driven）：可以直接用 /design-html
- 有具体描述（freeform）：可以直接用 /design-html
- 没有任何方向感：先用 /design-shotgun 看图找感觉

> **本质区别**：shotgun 是"看图选方向"，html 是"把方向变成代码"。

---

## 关键设计决策汇总

| 设计决策 | 选择 | 理由 |
|---------|------|------|
| 布局引擎 | Pretext（计算布局） | CSS 近似无法处理真实 resize/高度计算 |
| 包大小 | 30KB 零依赖 | 可嵌入任何地方，无部署复杂度 |
| 产物存储 | `~/.gstack/` 而非项目目录 | 用户数据跨分支持久化 |
| 多框架支持 | 问用户要 vanilla/React/Svelte/Vue | 不假设技术栈 |
| 精化策略 | Edit（外科）而非 Write（重写） | 保留用户 contenteditable 编辑 |
| 内容策略 | 真实内容 | 让设计决策基于真实数据 |
| API 选择 | Smart Routing 按设计类型选 | 不同类型需要不同 Pretext 能力 |
| 预览方式 | localhost HTTP 服务器 | 避免 file:// CORS 问题 |
| 降级策略 | $D/$B 均可选，有降级方案 | 核心功能不依赖额外工具 |
| 页面范围 | 一次调用一个页面 | Scope 控制，避免复杂度爆炸 |

---

## Pretext 引擎原理一图流

```
┌─────────────────────────────────────────────────────────────────┐
│                      Pretext 引擎设计                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  测量阶段（昂贵，做一次）                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ prepare("Hello world", "16px Inter") → handle           │    │
│  │                                                          │    │
│  │ 内部：用浏览器 Canvas API 测量每个字形                     │    │
│  │ 缓存：字体+字符组合 → 宽度 mapping                        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                          │                                       │
│                          ↓                                       │
│  布局阶段（廉价，每次 resize）                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ layout(handle, maxWidth=600, lineHeight=24)              │    │
│  │ → { height: 48, lineCount: 2 }                          │    │
│  │                                                          │    │
│  │ 纯数学计算：已知每个字符宽度，按 maxWidth 换行              │    │
│  │ 亚毫秒级：1000 个元素 < 1ms                               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  关键洞察：测量贵，计算便宜                                        │
│  prepare() 贵 → 只在文本/字体变化时调用（一次）                   │
│  layout() 便宜 → 每次 resize 都可以调用（实时）                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

*本文档基于 `design-html/SKILL.md`（1180 行）整理。Pretext 库：[@chenglou/pretext](https://github.com/chenglou/pretext)。*
