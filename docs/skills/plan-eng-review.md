# `/plan-eng-review` 技能逐段中英对照注解

> 对应源文件：[`plan-eng-review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/plan-eng-review/SKILL.md.tmpl)（317 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: plan-eng-review
preamble-tier: 3
version: 1.0.0
description: |
  Eng manager-mode plan review. Lock in the execution plan — architecture,
  data flow, diagrams, edge cases, test coverage, performance. Walks through
  issues interactively with opinionated recommendations. Use when asked to
  "review the architecture", "engineering review", or "lock in the plan".
  Proactively suggest when the user has a plan or design doc and is about to
  start coding — to catch architecture issues before implementation. (gstack)
voice-triggers:
  - "tech review"
  - "technical review"
  - "plan engineering review"
benefits-from: [office-hours]
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - AskUserQuestion
  - Bash
  - WebSearch
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/plan-eng-review` 触发。
- **preamble-tier: 3**: Preamble 详细度级别 3（共 4 级）。包含完整的 repo 模式检测、Search Before Building 等上下文。只有 /ship、/qa 等用 tier 4。
- **description**: 工程经理模式的方案评审。锁定执行计划——架构、数据流、图表、边界情况、测试覆盖、性能。逐个问题交互式讨论，给出有立场的建议。当用户有方案/设计文档且准备开始写代码时，主动建议运行。
- **voice-triggers**: 语音转文字别名。用户说 "tech review" 时 Claude 识别为 `/plan-eng-review`。
- **benefits-from: [office-hours]**: 建议先运行 `/office-hours`。如果检测到已有 office-hours 的设计文档，会自动读取。
- **allowed-tools**: 允许的工具列表。注意**没有 Edit**——评审不改代码，只读取和分析。也没有 Agent——评审是串行交互的。

> **设计原理：为什么没有 Edit？**
> 这是刻意的约束。评审阶段不应该改代码——先锁定方案，再动手。如果允许 Edit，AI 可能在你还没确认方向时就开始修改文件。

---

## {{PREAMBLE}} 展开区

原文第 27 行是 `{{PREAMBLE}}`，在编译时会被 `resolvers/preamble.ts` 展开为约 200 行的前置上下文。Tier 3 的 preamble 包含：

1. **Bash 环境初始化**：环境变量、升级检查、session 追踪、telemetry
2. **Boil the Lake 原则**：gstack 的核心哲学——AI 让完整性变得廉价，不要走捷径
3. **语音指令**：Garry Tan 的工程风格——直接、具体、有立场
4. **AskUserQuestion 格式规范**：项目名 + 分支名 + 编号选项
5. **完整性原则**：DONE / DONE_WITH_CONCERNS / BLOCKED 三种完成状态
6. **上下文恢复**：会话压缩后如何重建上下文
7. **Repo 模式检测**：判断是否在 git 仓库内，以及是否有 CLAUDE.md
8. **Search Before Building**：三层知识体系（Layer 1/2/3）

> **注意**：Preamble 的内容不在 `.tmpl` 文件里——它是运行时动态生成的。这里只解释它的作用。

---

## 原文第 29-31 行：Plan Review Mode（评审模式声明）

> **原文**：
> ```
> # Plan Review Mode
>
> Review this plan thoroughly before making any code changes. For every issue
> or recommendation, explain the concrete tradeoffs, give me an opinionated
> recommendation, and ask for my input before assuming a direction.
> ```

**中文**：方案评审模式。在做任何代码变更之前彻底审查这个方案。对于每个问题或建议，解释具体的取舍，给出有立场的推荐，并在假定方向之前征求我的意见。

> **设计原理**：三个关键词——"concrete tradeoffs"（具体取舍，不是泛泛而谈）、"opinionated recommendation"（有立场，不是"这个也行那个也行"）、"ask for my input"（最终决策权在人）。

---

## 原文第 33-34 行：Priority hierarchy（优先级层次）

> **原文**：
> ```
> ## Priority hierarchy
> If the user asks you to compress or the system triggers context compaction:
> Step 0 > Test diagram > Opinionated recommendations > Everything else.
> Never skip Step 0 or the test diagram. Do not preemptively warn about
> context limits -- the system handles compaction automatically.
> ```

**中文**：如果用户要求压缩或系统触发上下文压缩：Step 0 > 测试图 > 有立场的建议 > 其余一切。永远不要跳过 Step 0 或测试图。不要提前警告上下文限制——系统会自动处理压缩。

> **设计原理**：Claude 的上下文窗口有限。当空间不够时，这条规则告诉 AI 什么最重要。Step 0（范围挑战）和测试图是整个评审中最不可替代的产出——如果只能保留两样东西，就是这两个。

---

## 原文第 36-42 行：Engineering Preferences（工程偏好）

> **原文**：
> ```
> ## My engineering preferences (use these to guide your recommendations):
> * DRY is important—flag repetition aggressively.
> * Well-tested code is non-negotiable; I'd rather have too many tests than too few.
> * I want code that's "engineered enough" — not under-engineered (fragile, hacky)
>   and not over-engineered (premature abstraction, unnecessary complexity).
> * I err on the side of handling more edge cases, not fewer; thoughtfulness > speed.
> * Bias toward explicit over clever.
> * Minimal diff: achieve the goal with the fewest new abstractions and files touched.
> ```

**逐条翻译**：

| 原文 | 中文 | 实际影响 |
|------|------|---------|
| DRY is important—flag repetition aggressively | DRY 很重要——积极标记重复 | AI 会主动指出重复代码 |
| Well-tested code is non-negotiable | 良好测试的代码不可妥协 | 宁多勿少 |
| "engineered enough" — not under-engineered and not over-engineered | "恰好够工程化"——不糙也不过度 | 拒绝提前抽象，也拒绝临时代码 |
| handling more edge cases, not fewer; thoughtfulness > speed | 处理更多边界情况；深思熟虑 > 速度 | AI 会主动问"如果 X 发生怎么办" |
| Bias toward explicit over clever | 偏向显式而非聪明 | 拒绝炫技式代码 |
| Minimal diff | 最小差异 | 用最少的新抽象和文件改动达成目标 |

> **设计原理**：这些偏好被硬编码进每次评审的上下文。这让 AI 不是泛泛地"评审代码"，而是**按照特定工程哲学**来评审。每个推荐必须映射回这些偏好之一（见后面的"How to ask questions"）。

---

## 原文第 44-64 行：Cognitive Patterns（认知模式）

> **原文**：
> ```
> ## Cognitive Patterns — How Great Eng Managers Think
>
> These are not additional checklist items. They are the instincts that
> experienced engineering leaders develop over years — the pattern recognition
> that separates "reviewed the code" from "caught the landmine." Apply them
> throughout your review.
> ```

**中文**：这些不是额外的检查项。它们是优秀工程 leader 多年积累的本能——区分"我审了代码"和"我抓住了地雷"的模式识别能力。在整个评审过程中运用它们。

### 15 条逐条翻译

| # | 英文 | 中文 | 来源 | 应用场景 |
|---|------|------|------|---------|
| 1 | **State diagnosis** — Teams exist in four states: falling behind, treading water, repaying debt, innovating. Each demands a different intervention. | **状态诊断**——团队处于四种状态之一：落后、踩水、还债、创新。不同状态需要不同干预。 | Larson《An Elegant Puzzle》 | 判断团队当前应该做什么 |
| 2 | **Blast radius instinct** — Every decision evaluated through "what's the worst case and how many systems/people does it affect?" | **爆炸半径本能**——每个决定都通过"最坏情况影响多少系统/人"来评估。 | 通用 | 评估变更风险 |
| 3 | **Boring by default** — "Every company gets about three innovation tokens." Everything else should be proven technology. | **默认无聊**——每个公司约有三个创新代币，其余用成熟技术。 | McKinley《选择无聊的技术》 | 挑战新基础设施引入 |
| 4 | **Incremental over revolutionary** — Strangler fig, not big bang. Canary, not global rollout. | **渐进优于革命**——勒死法，不是大爆炸。灰度发布，不是全量上线。 | Fowler | 评估迁移策略 |
| 5 | **Systems over heroes** — Design for tired humans at 3am, not your best engineer on their best day. | **系统优于英雄**——为凌晨 3 点的疲惫人类设计，不是为状态最好的顶级工程师。 | SRE 思想 | 评审 on-call 友好度 |
| 6 | **Reversibility preference** — Feature flags, A/B tests, incremental rollouts. Make the cost of being wrong low. | **可逆性偏好**——Feature flag、A/B 测试、增量发布。让犯错成本低。 | 通用 | 评估部署策略 |
| 7 | **Failure is information** — Blameless postmortems, error budgets, chaos engineering. | **故障即信息**——无惩罚事后复盘，error budget，混沌工程。 | Allspaw / Google SRE | 评审错误处理 |
| 8 | **Org structure IS architecture** — Conway's Law in practice. | **组织结构即架构**——Conway 定律的实践。 | Team Topologies | 评审模块边界 |
| 9 | **DX is product quality** — Slow CI, bad local dev, painful deploys → worse software, higher attrition. | **开发者体验即产品质量**——CI 慢 → 软件差 → 人员流失。 | 通用 | 评审 CI/DX |
| 10 | **Essential vs accidental complexity** — "Is this solving a real problem or one we created?" | **本质 vs 偶然复杂度**——"这是在解决真实问题还是我们自造的问题？" | Brooks《没有银弹》 | 质疑每一层抽象 |
| 11 | **Two-week smell test** — If a competent engineer can't ship a small feature in two weeks, you have an onboarding problem. | **两周气味测试**——普通工程师两周内无法上手新功能 = 架构问题。 | 通用 | 评审上手难度 |
| 12 | **Glue work awareness** — Recognize invisible coordination work. | **胶水工作意识**——识别无形的协调工作，重视它，但别让人只做它。 | Reilly《Staff Engineer 之道》 | 评审工作分配 |
| 13 | **Make the change easy, then make the easy change** — Refactor first, implement second. | **先让改变容易，再做容易的改变**——先重构，再实现。永远不要同时改结构+行为。 | Beck | 评审变更策略 |
| 14 | **Own your code in production** — No wall between dev and ops. | **在生产中拥有你的代码**——开发和运维之间没有墙。 | Majors | 评审运维方案 |
| 15 | **Error budgets over uptime targets** — SLO of 99.9% = 0.1% downtime budget to spend on shipping. | **Error budget 优于可用率目标**——99.9% SLO = 0.1% 的宕机预算，可以用来发货。 | Google SRE | 评审可靠性目标 |

> **原文第 64 行的指导**：
> ```
> When evaluating architecture, think "boring by default." When reviewing tests,
> think "systems over heroes." When assessing complexity, ask Brooks's question.
> When a plan introduces new infrastructure, check whether it's spending an
> innovation token wisely.
> ```
>
> **中文**：评审架构时想"默认无聊"。评审测试时想"系统优于英雄"。评估复杂度时问 Brooks 的问题。方案引入新基础设施时，检查创新代币花得是否值得。

> **设计原理**：纯粹的检查列表容易变成机械操作。把**思维模式**嵌进上下文，让 AI 做出像有 15 年经验的工程 leader 的判断。这些不是"检查了就打勾"，而是"用这种思维方式看问题"。

---

## 原文第 66-69 行：Documentation and diagrams（文档和图表）

> **原文**：
> ```
> * I value ASCII art diagrams highly — for data flow, state machines,
>   dependency graphs, processing pipelines, and decision trees.
> * For particularly complex designs, embed ASCII diagrams directly in code comments.
> * Diagram maintenance is part of the change. Stale diagrams are worse than
>   no diagrams — they actively mislead.
> ```

**中文**：
- 我非常重视 ASCII 图表——用于数据流、状态机、依赖图、处理管线和决策树。
- 特别复杂的设计要在代码注释里直接嵌入 ASCII 图表。
- **图表维护是变更的一部分**。过时的图表比没有图表更糟——它们积极误导。发现过时的图表要标记，即使不在当前变更范围内。

> **设计原理**："Stale diagrams are worse than no diagrams" 这句话是关键——很多项目有文档但从不更新，导致新人照着过时文档走弯路。

---

## 原文第 71-83 行：BEFORE YOU START — Design Doc Check

> **原文**：
> ```bash
> setopt +o nomatch 2>/dev/null || true  # zsh compat
> SLUG=$(~/.claude/skills/gstack/browse/bin/remote-slug 2>/dev/null || ...)
> BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null | tr '/' '-' || ...)
> DESIGN=$(ls -t ~/.gstack/projects/$SLUG/*-$BRANCH-design-*.md 2>/dev/null | head -1)
> [ -z "$DESIGN" ] && DESIGN=$(ls -t ~/.gstack/projects/$SLUG/*-design-*.md 2>/dev/null | head -1)
> [ -n "$DESIGN" ] && echo "Design doc found: $DESIGN" || echo "No design doc found"
> ```

**中文**：在开始评审前，先搜索是否有 `/office-hours` 生成的设计文档。

**搜索策略**：
1. 先找**当前分支**对应的设计文档（`*-$BRANCH-design-*.md`）
2. 没找到就找**任何**设计文档（`*-design-*.md`）
3. 按修改时间排序取最新（`ls -t ... | head -1`）
4. `setopt +o nomatch` 是 zsh 兼容——zsh 的 glob 无匹配时报错，这行关闭该行为

> **设计原理**：如果用户先跑了 `/office-hours` 再跑 `/plan-eng-review`，设计文档就是方案的唯一真相源。如果有 `Supersedes:` 字段，说明这是修订版——要检查之前的版本了解改了什么。

---

## 原文第 84 行：{{BENEFITS_FROM}} 展开区

编译时替换为：如果检测到 `office-hours` 的设计文档，提示"上次 office-hours 的设计文档在 X，建议先读取"。

---

## 原文第 86-113 行：Step 0: Scope Challenge（范围挑战）

这是整个评审**最重要的一步**，放在所有评审之前。

### 检查项 1：现有代码

> **原文**：
> ```
> 1. What existing code already partially or fully solves each sub-problem?
>    Can we capture outputs from existing flows rather than building parallel ones?
> ```

**中文**：现有代码已经部分或完全解决了哪些子问题？能不能从已有流程捕获输出，而不是构建平行的新流程？

### 检查项 2：最小变更集

> **原文**：
> ```
> 2. What is the minimum set of changes that achieves the stated goal?
>    Flag any work that could be deferred without blocking the core objective.
>    Be ruthless about scope creep.
> ```

**中文**：达成目标所需的最小变更集是什么？标记所有可以推迟而不阻塞核心目标的工作。对范围蔓延要无情。

### 检查项 3：复杂度检查

> **原文**：
> ```
> 3. Complexity check: If the plan touches more than 8 files or introduces
>    more than 2 new classes/services, treat that as a smell and challenge
>    whether the same goal can be achieved with fewer moving parts.
> ```

**中文**：复杂度检查——如果方案涉及超过 **8 个文件**或引入超过 **2 个新类/服务**，视为异味，质疑能否用更少的活动部件达成相同目标。

> **设计原理**：8 文件 / 2 新类是经验阈值。超过这个数字通常意味着方案在"构建平台"而不是"解决问题"。

### 检查项 4：搜索检查

> **原文**：
> ```
> 4. Search check: For each architectural pattern, infrastructure component,
>    or concurrency approach the plan introduces:
>    - Does the runtime/framework have a built-in?
>    - Is the chosen approach current best practice?
>    - Are there known footguns?
>
>    Annotate recommendations with [Layer 1], [Layer 2], [Layer 3], or [EUREKA].
> ```

**中文**：对方案引入的每个架构模式、基础设施组件或并发方案：
- 运行时/框架有没有内置方案？
- 选择的方案是当前最佳实践吗？
- 有没有已知的坑？

用 **[Layer 1]**（久经考验）、**[Layer 2]**（新但流行）、**[Layer 3]**（从第一原理出发）或 **[EUREKA]**（发现标准方案在这个场景下是错的）标注。

> **设计原理**：EUREKA 标注是最有价值的——当你发现"所有人都这么做但在我们的场景下是错的"，这是真正的架构洞察。

### 检查项 5a：TODOS 交叉引用

> **原文**：
> ```
> 5. TODOS cross-reference: Read TODOS.md if it exists. Are any deferred items
>    blocking this plan? Can any deferred items be bundled into this PR without
>    expanding scope?
> ```

**中文**：读 `TODOS.md`。有没有推迟的项阻塞这个方案？有没有推迟的项可以不扩大范围地捆绑进这个 PR？

### 检查项 5b：完整性检查

> **原文**：
> ```
> 5. Completeness check: Is the plan doing the complete version or a shortcut?
>    With AI-assisted coding, the cost of completeness (100% test coverage, full
>    edge case handling, complete error paths) is 10-100x cheaper than with a
>    human team. If the plan proposes a shortcut that saves human-hours but only
>    saves minutes with CC+gstack, recommend the complete version. Boil the lake.
> ```

**中文**：方案是做完整版还是走捷径？在 AI 辅助编码下，完整性的成本（100% 测试覆盖、完整边界处理、完整错误路径）比人类团队便宜 10-100 倍。如果方案提出的捷径在人力时间上省了很多但在 CC+gstack 下只省了几分钟，推荐完整版。**Boil the lake**（清空湖底）。

> **设计原理**：这是 gstack 的核心哲学——AI 让"做完整的事"几乎免费。"Ship the shortcut" 是旧时代的思维，当时人力工程时间是瓶颈。

### 检查项 6：分发检查

> **原文**：
> ```
> 6. Distribution check: If the plan introduces a new artifact type (CLI binary,
>    library package, container image, mobile app), does it include the
>    build/publish pipeline? Code without distribution is code nobody can use.
> ```

**中文**：如果方案引入新的产物类型（CLI 二进制、库包、容器镜像、移动应用），是否包含构建/发布管道？没有分发的代码是没人能用的代码。

### 触发后的行为

> **原文**：
> ```
> If the complexity check triggers (8+ files or 2+ new classes/services),
> proactively recommend scope reduction via AskUserQuestion.
>
> Critical: Once the user accepts or rejects a scope reduction recommendation,
> commit fully. Do not re-argue for smaller scope during later review sections.
> ```

**中文**：如果复杂度检查触发，主动通过 AskUserQuestion 建议缩减范围。**关键规则**：一旦用户接受或拒绝范围缩减，就全身心投入。不要在后续评审环节中重新争论更小的范围。

> **设计原理**：防止 AI 在 Step 0 被用户否决后，在 Section 2 或 3 里偷偷缩减范围或跳过组件。一次争论，一次决策，然后执行。

---

## 原文第 115-117 行：Anti-skip rule（禁止跳过规则）

> **原文**：
> ```
> **Anti-skip rule:** Never condense, abbreviate, or skip any review section
> (1-4) regardless of plan type (strategy, spec, code, infra). Every section
> in this skill exists for a reason. "This is a strategy doc so implementation
> sections don't apply" is always wrong — implementation details are where
> strategy breaks down.
> ```

**中文**：禁止跳过规则——无论方案类型（策略、规格、代码、基础设施），永远不要压缩、简略或跳过任何评审章节（1-4）。"这是策略文档所以实现部分不适用"永远是错的——实现细节正是策略崩溃的地方。如果某个章节真的没有发现，说"No issues found"然后继续——但你必须评估它。

> **设计原理**：AI 经常"优化"掉它认为不相关的部分。但工程评审的价值恰恰在于"看似不相关的部分发现了问题"。

---

## 原文第 119 行：{{LEARNINGS_SEARCH}} 展开区

编译时替换为：搜索 `~/.gstack/learnings/` 中与当前项目相关的历史学习记录。如果之前的评审或调试中积累了相关经验（比如"这个项目的 auth 模块有个已知的竞态"），会在这里呈现。

---

## 原文第 121-132 行：Section 1 — Architecture Review

> **原文**：
> ```
> ### 1. Architecture review
> Evaluate:
> * Overall system design and component boundaries.
> * Dependency graph and coupling concerns.
> * Data flow patterns and potential bottlenecks.
> * Scaling characteristics and single points of failure.
> * Security architecture (auth, data access, API boundaries).
> * Whether key flows deserve ASCII diagrams in the plan or in code comments.
> * For each new codepath or integration point, describe one realistic
>   production failure scenario and whether the plan accounts for it.
> * Distribution architecture: If this introduces a new artifact (binary,
>   package, container), how does it get built, published, and updated?
> ```

**中文**：评审以下维度：
1. 整体系统设计和组件边界
2. 依赖图和耦合问题
3. 数据流模式和潜在瓶颈
4. 扩展特性和单点故障
5. 安全架构（认证、数据访问、API 边界）
6. 关键流程是否需要 ASCII 图
7. **每个新代码路径或集成点，描述一个现实的生产故障场景，以及方案是否考虑了它**
8. **分发架构**：新产物如何构建、发布、更新？

> **设计原理**：第 7 点是最有价值的——不是"可能出什么问题"而是"具体描述一个真实的故障场景"。比如："如果支付服务超时 30 秒，用户会看到什么？订单状态会怎样？重试安全吗？"

### STOP 规则

> **原文**：
> ```
> **STOP.** For each issue found in this section, call AskUserQuestion
> individually. One issue per call. Present options, state your recommendation,
> explain WHY. Do NOT batch multiple issues into one AskUserQuestion. Only
> proceed to the next section after ALL issues in this section are resolved.
> ```

**中文**：**停。** 本节中发现的每个问题，单独调用 AskUserQuestion。一个问题一次调用。展示选项，陈述你的推荐，解释为什么。不要把多个问题合并到一个 AskUserQuestion。只有在本节所有问题都解决后才进入下一节。

> **设计原理**：为什么"一个问题一次询问"？
> - 批量询问时用户容易只回答第一个
> - 多问题混合后决策质量下降
> - 无法记录哪个问题选了哪个方案
> - 独立询问让每个决策可追溯

---

## 原文第 134 行：{{CONFIDENCE_CALIBRATION}} 展开区

编译时替换为置信度校准系统——每个发现标注置信度分数，防止"为了完整性"列出大量低置信度的理论风险。

---

## 原文第 136-145 行：Section 2 — Code Quality Review

> **原文**：
> ```
> ### 2. Code quality review
> Evaluate:
> * Code organization and module structure.
> * DRY violations—be aggressive here.
> * Error handling patterns and missing edge cases (call these out explicitly).
> * Technical debt hotspots.
> * Areas that are over-engineered or under-engineered relative to my preferences.
> * Existing ASCII diagrams in touched files — are they still accurate?
> ```

**中文**：评审以下维度：
1. 代码组织和模块结构
2. **DRY 违规——在这里要积极**（对应工程偏好第 1 条）
3. 错误处理模式和缺失的边界情况（**明确指出**）
4. 技术债热点
5. 相对于工程偏好，哪里过度工程化或不够工程化
6. 被修改文件中的已有 ASCII 图——变更后还准确吗？

然后同样的 **STOP 规则**——每个问题单独 AskUserQuestion。

---

## 原文第 147-153 行：Section 3 — Test Review

> **原文**：
> ```
> ### 3. Test review
>
> {{TEST_COVERAGE_AUDIT_PLAN}}
>
> For LLM/prompt changes: check the "Prompt/LLM changes" file patterns listed
> in CLAUDE.md. If this plan touches ANY of those patterns, state which eval
> suites must be run, which cases should be added, and what baselines to
> compare against.
> ```

**中文**：
- `{{TEST_COVERAGE_AUDIT_PLAN}}` 展开为测试覆盖率审计方案——生成测试覆盖图，可视化每个功能路径对应的测试用例。
- 如果方案涉及 LLM/prompt 变更：检查 CLAUDE.md 中列出的 prompt 文件模式，说明必须运行哪些 eval 套件、添加哪些 case、与什么基线比较。

然后 **STOP 规则**。

---

## 原文第 155-162 行：Section 4 — Performance Review

> **原文**：
> ```
> ### 4. Performance review
> Evaluate:
> * N+1 queries and database access patterns.
> * Memory-usage concerns.
> * Caching opportunities.
> * Slow or high-complexity code paths.
> ```

**中文**：评审以下维度：
1. N+1 查询和数据库访问模式
2. 内存使用问题
3. 缓存机会
4. 慢或高复杂度的代码路径

然后 **STOP 规则**。

---

## 原文第 164 行：{{CODEX_PLAN_REVIEW}} 展开区

如果安装了 OpenAI Codex CLI，这里会展开为"用 Codex 对方案做独立评审"的指令。Codex 是不同的 AI 系统——跨模型的共识是强信号。

---

## 原文第 166-172 行：Outside Voice Integration Rule

> **原文**：
> ```
> Outside voice findings are INFORMATIONAL until the user explicitly approves
> each one. Do NOT incorporate outside voice recommendations into the plan
> without presenting each finding via AskUserQuestion and getting explicit
> approval. This applies even when you agree with the outside voice.
> Cross-model consensus is a strong signal — present it as such — but the
> user makes the decision.
> ```

**中文**：外部声音的发现在用户明确批准之前只是**信息性的**。即使你同意外部声音的建议，也不能不经 AskUserQuestion 就采纳。跨模型共识是强信号——如此呈现它——但用户做决定。

> **设计原理**：防止两个 AI 系统达成共识后绕过人类决策。即使 Claude + Codex 都说"应该这样做"，最终还是人来决定。

---

## 原文第 174-182 行：CRITICAL RULE — How to ask questions

> **原文**（逐条）：
> ```
> * One issue = one AskUserQuestion call.
> * Describe the problem concretely, with file and line references.
> * Present 2-3 options, including "do nothing" where reasonable.
> * For each option, specify: effort (human: ~X / CC: ~Y), risk, maintenance burden.
>   If the complete option is only marginally more effort than the shortcut
>   with CC, recommend the complete option.
> * Map the reasoning to my engineering preferences above.
> * Label with issue NUMBER + option LETTER (e.g., "3A", "3B").
> * Escape hatch: If no issues, say so. If obvious fix, just state it.
>   Only AskUserQuestion when there's a genuine decision with meaningful tradeoffs.
> ```

**中文**：
1. 一个问题 = 一次 AskUserQuestion 调用
2. 具体描述问题，带文件和行号引用
3. 展示 2-3 个选项，合理时包含"不做"选项
4. 每个选项一行说明：努力（人力: ~X / CC: ~Y）、风险、维护负担。如果完整选项在 CC 下只比捷径多花一点，推荐完整选项
5. **把推理映射到上面的工程偏好**——一句话连接你的推荐和具体偏好
6. 用 数字+字母 标记（如 "3A", "3B"）
7. 逃生舱：没问题就说没问题。明显的修复直接说明。只在有真正的权衡决策时用 AskUserQuestion

> **设计原理**：
> - `effort (human: ~X / CC: ~Y)` 是 gstack 的"AI 压缩比"概念——让用户看到"做完整版在 CC 下其实不贵"
> - "Map to engineering preferences" 确保每个推荐不是随机的而是锚定在声明的偏好上
> - "Escape hatch" 防止 AI 为了"完整性"在没有真正问题的地方也强制提问

---

## 原文第 184-217 行：Required Outputs（必须输出）

### "NOT in scope" 区（第 186-187 行）

> **原文**：
> ```
> Every plan review MUST produce a "NOT in scope" section listing work that was
> considered and explicitly deferred, with a one-line rationale for each item.
> ```

**中文**：每次评审**必须**产出"NOT in scope"区，列出被考虑过但明确推迟的工作，每项附一行理由。

> **设计原理**：让"我们考虑过 X 但决定不做"变成明确记录。防止以后有人问"为什么没做 X"时无法回答。

### "What already exists" 区（第 189-190 行）

> **原文**：
> ```
> List existing code/flows that already partially solve sub-problems in this
> plan, and whether the plan reuses them or unnecessarily rebuilds them.
> ```

**中文**：列出已经部分解决这个方案中子问题的已有代码/流程，以及方案是复用了它们还是不必要地重建了它们。

### TODOS.md 更新（第 192-205 行）

> **原文**：
> ```
> After all review sections are complete, present each potential TODO as its
> own individual AskUserQuestion. Never batch TODOs — one per question.
>
> For each TODO, describe:
> * What: One-line description
> * Why: The concrete problem it solves
> * Pros: What you gain
> * Cons: Cost, complexity, or risks
> * Context: Enough detail for someone picking this up in 3 months
> * Depends on / blocked by
>
> Options: A) Add to TODOS.md  B) Skip  C) Build it now
>
> Do NOT just append vague bullet points. A TODO without context is worse than
> no TODO — it creates false confidence.
> ```

**中文**：每个 TODO 单独 AskUserQuestion，永远不批量。每个 TODO 包含：What、Why、Pros、Cons、Context（3 个月后有人拿起来能理解）、Depends on。选项：A) 加到 TODOS.md B) 跳过 C) 现在就做。

> **设计原理**：vague TODO 是假自信——"记下来了"但实际丢失了推理过程。强制 6 个字段确保 TODO 有足够上下文。

### Failure Modes（第 210-216 行）

> **原文**：
> ```
> For each new codepath, list one realistic way it could fail in production
> and whether:
> 1. A test covers that failure
> 2. Error handling exists for it
> 3. The user would see a clear error or a silent failure
>
> If no test AND no error handling AND would be silent → critical gap.
> ```

**中文**：每个新代码路径，列出一个现实的生产故障方式，以及：测试覆盖了吗？有错误处理吗？用户会看到清晰的错误还是静默失败？如果**三者都没有**→ **关键缺口**。

> **设计原理**：无测试 + 无错误处理 + 静默失败 = 最危险的组合。数据丢失、事务回滚、请求超时——这些在生产中最难排查。

### Worktree 并行化策略（第 218-243 行）

> **原文**：
> ```
> Analyze the plan's implementation steps for parallel execution opportunities.
> Skip if: all steps touch the same primary module, or fewer than 2 independent
> workstreams. Otherwise produce:
>
> 1. Dependency table (step | modules touched | depends on)
> 2. Parallel lanes (group by shared modules + dependencies)
> 3. Execution order (which lanes launch in parallel, which wait)
> 4. Conflict flags (two lanes touching same module)
> ```

**中文**：分析方案的实现步骤，寻找并行执行机会。如果所有步骤涉及同一个模块或少于 2 个独立工作流，写"顺序实现，无并行化机会"。否则产出：

1. **依赖表**——每步涉及的模块（目录级，不是文件级）和依赖
2. **并行车道**——无共享模块且无依赖的步骤放在不同车道
3. **执行顺序**——哪些车道并行启动，哪些等待
4. **冲突标记**——两个并行车道涉及同一模块目录

> **设计原理**：利用 Claude Code 的 Agent 工具 + git worktree，一个人可以同时推进多条开发线。传统上需要一个小团队协作的事，现在一个人用两个 Claude Code 窗口就能做。

### Completion Summary（第 245-258 行）

> **原文**：
> ```
> - Step 0: Scope Challenge — ___ (scope accepted / scope reduced)
> - Architecture Review: ___ issues found
> - Code Quality Review: ___ issues found
> - Test Review: diagram produced, ___ gaps identified
> - Performance Review: ___ issues found
> - NOT in scope: written
> - What already exists: written
> - TODOS.md updates: ___ items proposed
> - Failure modes: ___ critical gaps flagged
> - Outside voice: ran / skipped
> - Parallelization: ___ lanes, ___ parallel / ___ sequential
> - Lake Score: X/Y recommendations chose complete option
> ```

**中文**：评审结束时填写完成摘要，让用户一眼看到所有发现。Lake Score 追踪"多少推荐选了完整版"——体现 Boil the Lake 原则的执行度。

---

## 原文第 260-261 行：Retrospective Learning

> **原文**：
> ```
> Check the git log for this branch. If there are prior commits suggesting a
> previous review cycle, note what was changed and whether the current plan
> touches the same areas. Be more aggressive reviewing areas that were
> previously problematic.
> ```

**中文**：检查这个分支的 git log。如果之前有评审驱动的重构或回退，标注并对之前有问题的区域更积极地评审。

---

## 原文第 263-267 行：Formatting Rules

> **原文**：
> ```
> * NUMBER issues (1, 2, 3...) and LETTERS for options (A, B, C...).
> * Label with NUMBER + LETTER (e.g., "3A", "3B").
> * One sentence max per option. Pick in under 5 seconds.
> * After each review section, pause and ask for feedback before moving on.
> ```

**中文**：问题用数字编号，选项用字母。标签格式 "3A", "3B"。每个选项最多一句话——5 秒内能选。每个评审章节结束后暂停，征求反馈后再继续。

---

## 原文第 269-291 行：Review Log

> **原文**：
> ```bash
> ~/.claude/skills/gstack/bin/gstack-review-log '{"skill":"plan-eng-review",
>   "timestamp":"TIMESTAMP","status":"STATUS","unresolved":N,
>   "critical_gaps":N,"issues_found":N,"mode":"MODE","commit":"COMMIT"}'
> ```

**中文**：将评审结果写入 `~/.gstack/reviews/review-log.jsonl`。

字段含义：
- **TIMESTAMP**: ISO 8601 时间
- **STATUS**: "clean"（0 未解决决策且 0 关键缺口）或 "issues_open"
- **unresolved**: 未解决决策数
- **critical_gaps**: 关键缺口数（来自 Failure Modes）
- **issues_found**: 所有评审章节的总问题数
- **MODE**: FULL_REVIEW / SCOPE_REDUCED
- **COMMIT**: `git rev-parse --short HEAD`

> **设计原理**：这条数据被 `/ship` 的评审看板读取。如果工程评审有未解决问题，`/ship` 会发出警告。

---

## 原文第 292-313 行：Review Chaining（评审链）

> **原文**（摘要）：
> - 如果有 UI 变更且没有设计评审 → 建议 `/plan-design-review`
> - 如果是重大产品变更且没有 CEO 评审 → 软性提及 `/plan-ceo-review`
> - 标注已有评审的陈旧性（commit hash 漂移）
> - 如果不需要额外评审 → "All relevant reviews complete. Run /ship when ready."

**中文**：评审看板显示后，检查是否需要其他评审。用 AskUserQuestion 只展示适用的选项：
- A) 运行 /plan-design-review（仅当检测到 UI 范围且无设计评审）
- B) 运行 /plan-ceo-review（仅当重大产品变更且无 CEO 评审）
- C) 准备实现——完成后运行 /ship

---

## 原文第 315-317 行：Unresolved Decisions

> **原文**：
> ```
> If the user does not respond to an AskUserQuestion or interrupts to move on,
> note which decisions were left unresolved. At the end of the review, list
> these as "Unresolved decisions that may bite you later" — never silently
> default to an option.
> ```

**中文**：如果用户没有回应某个 AskUserQuestion 或中断跳过，记录哪些决策未解决。在评审结束时列出"**可能在以后咬你一口的未解决决策**"——永远不要静默默认某个选项。

> **设计原理**：这是最后的安全网。AI 不会"帮你选了"然后假装一切正常——未回答的问题会被明确标记为风险。

---

## 整体流程总结图

```
/plan-eng-review
       │
       ▼
┌──────────────────────────────────────────┐
│  BEFORE YOU START                        │
│  1. 搜索设计文档 (~/.gstack/)           │
│  2. 读取 benefits-from 历史              │
│  3. 搜索历史 learnings                   │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Step 0: Scope Challenge（最重要）        │
│  ├─ 1. 现有代码已解决？                  │
│  ├─ 2. 最小变更集？                      │
│  ├─ 3. 复杂度检查（>8 文件 / >2 新类）  │
│  ├─ 4. 搜索检查（有内置方案？）          │
│  ├─ 5a. TODOS 交叉引用                   │
│  ├─ 5b. 完整性检查（Boil the Lake）      │
│  └─ 6. 分发检查（有构建管道？）          │
│  触发→ AskUserQuestion 建议缩减范围     │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  四轮评审（每轮结束 STOP + AskUser）      │
│                                          │
│  1. Architecture（8 维度 + 故障场景）    │
│     └→ 每个问题单独 AskUserQuestion     │
│                                          │
│  2. Code Quality（6 维度，DRY 要积极）   │
│     └→ 每个问题单独 AskUserQuestion     │
│                                          │
│  3. Test（覆盖率图 + LLM eval 范围）     │
│     └→ 每个问题单独 AskUserQuestion     │
│                                          │
│  4. Performance（N+1 / 内存 / 缓存）     │
│     └→ 每个问题单独 AskUserQuestion     │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Required Outputs                        │
│  ├─ NOT in scope 区                      │
│  ├─ What already exists 区               │
│  ├─ TODOS.md 更新（每个单独 AskUser）    │
│  ├─ Diagrams（ASCII 图 + 建议嵌入位置） │
│  ├─ Failure modes（关键缺口标记）        │
│  ├─ Worktree 并行化策略                  │
│  └─ Completion Summary + Lake Score      │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│  Review Log → ~/.gstack/reviews/         │
│  供 /ship 评审看板读取                   │
├──────────────────────────────────────────┤
│  Review Chaining                         │
│  建议：/plan-design-review?              │
│  或：/plan-ceo-review?                   │
│  或："All reviews complete. /ship when ready" │
├──────────────────────────────────────────┤
│  Unresolved Decisions                    │
│  "可能以后咬你一口的未解决决策"          │
└──────────────────────────────────────────┘
```

---

## 设计核心思路总结

| 设计决策 | 原因 | 原文行号 |
|---------|------|---------|
| 没有 Edit 工具 | 评审不改代码 | 17-24 |
| Step 0 最优先 | 先控制范围再评审 | 33-34, 86-113 |
| 15 个认知模式 | 用思维方式而非检查列表 | 44-64 |
| STOP 规则（一问一答） | 决策可追溯 | 132, 145, 153, 162 |
| Anti-skip rule | 防止跳过"不相关"的部分 | 117 |
| 工程偏好锚定 | 每个推荐映射到声明的偏好 | 180 |
| effort (human/CC) | 展示 AI 压缩比 | 179 |
| Failure Modes 三连检 | 无测试+无处理+静默=关键缺口 | 210-216 |
| Worktree 并行化 | 一个人并行推进多条线 | 218-243 |
| Lake Score | 量化 Boil the Lake 执行度 | 258 |
| Review Log | 供 /ship 评审看板使用 | 269-291 |
| Unresolved Decisions | 未回答的问题不静默默认 | 315-317 |
