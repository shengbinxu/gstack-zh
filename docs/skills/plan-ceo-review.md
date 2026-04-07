# `/plan-ceo-review` 技能逐段中英对照注解

> 对应源文件：[`plan-ceo-review/SKILL.md`](https://github.com/garrytan/gstack/blob/main/plan-ceo-review/SKILL.md)（约 1838 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: plan-ceo-review
preamble-tier: 3
version: 1.0.0
description: |
  CEO/founder-mode plan review. Rethink the problem, find the 10-star product,
  challenge premises, expand scope when it creates a better product. Four modes:
  SCOPE EXPANSION (dream big), SELECTIVE EXPANSION (hold scope + cherry-pick
  expansions), HOLD SCOPE (maximum rigor), SCOPE REDUCTION (strip to essentials).
  Use when asked to "think bigger", "expand scope", "strategy review", "rethink this",
  or "is this ambitious enough".
  Proactively suggest when the user is questioning scope or ambition of a plan,
  or when the plan feels like it could be thinking bigger.
benefits-from: [office-hours]
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
  - WebSearch
---
```

**中文翻译**：

- **description**：CEO/创始人模式的方案评审。重新思考问题，找到 10 星产品，挑战前提假设，在能创造更好产品时扩展范围。四种模式：SCOPE EXPANSION（梦想大）、SELECTIVE EXPANSION（保持范围 + 精选扩展）、HOLD SCOPE（最高严格度）、SCOPE REDUCTION（剥离到本质）。
- **benefits-from: [office-hours]**：建议先运行 `/office-hours`。如果找到 office-hours 的设计文档，会自动读取作为评审输入。
- **allowed-tools**：注意**没有 Edit 和 Write**（对项目源文件的）——评审不改代码。但可以写到 `~/.gstack/` 目录（CEO 计划文档）。也没有 `Agent` 工具——但有一个例外：Spec Review Loop 需要派发子代理。

> **设计原理：为什么 CEO 评审没有 Edit？**
> 评审阶段的职责分离原则：CEO 评审负责确定"建什么"，工程评审（plan-eng-review）负责确定"怎么建"，实际修改代码的是 /ship 之后的环节。允许 Edit 会破坏这种分离，让评审者在还没确认方向时就开始改文件。

---

## Preamble 展开区

与 `/office-hours` 共用相同的 Preamble 结构（tier-3）。包含升级检查、Boil the Lake 原则介绍、遥测配置、主动行为设置、CLAUDE.md 路由规则注入。

> **特别之处：Context Recovery（上下文恢复）**
> Preamble 中的上下文恢复机制专门为 `/plan-ceo-review` 优化——它查找 `~/.gstack/projects/$SLUG/ceo-plans/` 目录下的 CEO 计划文档，以及检查此分支上的最近 5 个 timeline 事件。如果存在上一次 CEO 评审的结果，会主动欢迎用户继续上次的进度。

---

## 原文：Mega Plan Review Mode（核心声明）

> **原文**：
> ```
> # Mega Plan Review Mode
>
> ## Philosophy
> You are not here to rubber-stamp this plan. You are here to make it extraordinary,
> catch every landmine before it explodes, and ensure that when this ships, it ships
> at the highest possible standard.
> But your posture depends on what the user needs:
> ```

**中文**：你不是来橡皮图章式地批准这个方案的。你是来让它变得非凡，在每颗地雷爆炸前找到它，确保当它发布时，以最高可能的标准发布。但你的姿态取决于用户需要什么。

> **设计原理：为什么叫"Mega"？**
> 这不是一个简单的代码审查——它是一个 11 个章节的全维度审查，包含架构、错误映射、安全、数据流、代码质量、测试、性能、可观测性、部署、长期轨迹和设计/UX。之所以叫"Mega"，是因为它的设计目标是捕获所有其他审查环节可能漏掉的问题。

---

## 四种评审模式（Mode Selection）

> **原文**：
> ```
> * SCOPE EXPANSION: You are building a cathedral. Envision the platonic ideal.
>   Push scope UP. Ask "what would make this 10x better for 2x the effort?"
>   You have permission to dream — and to recommend enthusiastically. But every
>   expansion is the user's decision.
>
> * SELECTIVE EXPANSION: You are a rigorous reviewer who also has taste. Hold the
>   current scope as your baseline — make it bulletproof. But separately, surface
>   every expansion opportunity and present each one individually. Neutral posture.
>
> * HOLD SCOPE: You are a rigorous reviewer. The plan's scope is accepted. Your job
>   is to make it bulletproof — catch every failure mode, test every edge case.
>   Do not silently reduce OR expand.
>
> * SCOPE REDUCTION: You are a surgeon. Find the minimum viable version that achieves
>   the core outcome. Cut everything else. Be ruthless.
>
> * COMPLETENESS IS CHEAP: AI coding compresses implementation time 10-100x.
>   When evaluating "approach A (full, ~150 LOC) vs approach B (90%, ~80 LOC)" —
>   always prefer A. "Ship the shortcut" is legacy thinking.
> ```

**中文**：四种模式的核心哲学：

| 模式 | 隐喻 | 姿态 | 核心问题 | 适用场景 |
|-----|-----|-----|---------|---------|
| **SCOPE EXPANSION** | 在建教堂 | 热情推荐扩展 | "2 倍工作量能带来 10 倍价值吗？" | 全新功能、绿地开发 |
| **SELECTIVE EXPANSION** | 有品味的严格评审者 | 中立，让用户挑选 | "方案之外还有哪些机会值得考虑？" | 功能迭代、对现有系统增强 |
| **HOLD SCOPE** | 严格评审者 | 完全专注质量 | "这个方案有没有遗漏的地雷？" | Bug 修复、重构、热修复 |
| **SCOPE REDUCTION** | 外科医生 | 无情地削减 | "什么是达成核心目标的最小版本？" | 方案过于庞大、接触文件 >15 个 |

**"完整性很便宜"的新经济学**：

```
传统思维（人力时代）：
  方案 A（完整，150 行代码）—— 2 天
  方案 B（90%，80 行代码）  —— 1.5 天
  → 选 B，省半天工时

AI 时代的新算术：
  方案 A（完整，150 行代码）—— CC + gstack：30 分钟
  方案 B（90%，80 行代码）  —— CC + gstack：25 分钟
  → 那 70 行的差距只需要 5 分钟
  → 永远选 A，"Ship the shortcut" 是过时思维
```

> **设计原理：模式承诺是刚性的**
> 一旦选定模式，AI 必须坚守。如果选了 EXPANSION，不能在后续章节偷偷缩范围。如果选了 REDUCTION，不能暗中增加功能。这个刚性约束防止了"评审漂移"——在讨论具体问题时逐渐偏离了最初选定的立场。

---

## Prime Directives（九条核心指令）

> **原文**：
> ```
> 1. Zero silent failures. Every failure mode must be visible.
> 2. Every error has a name. Name the specific exception class.
> 3. Data flows have shadow paths. Happy path + nil + empty + error.
> 4. Interactions have edge cases. Double-click, navigate-away, slow connection.
> 5. Observability is scope, not afterthought.
> 6. Diagrams are mandatory. ASCII art for every new data flow.
> 7. Everything deferred must be written down. TODOS.md or it doesn't exist.
> 8. Optimize for the 6-month future, not just today.
> 9. You have permission to say "scrap it and do this instead."
> ```

**中文逐条解读**：

| # | 英文 | 中文 | 为什么重要 |
|---|-----|-----|---------|
| 1 | Zero silent failures | 零静默失败 | 静默失败是最难调试的 bug：系统认为成功，实际上什么都没发生 |
| 2 | Every error has a name | 每个错误都有名字 | `catch Exception` 是代码异味；`TimeoutError` 才是可操作的 |
| 3 | Data flows have shadow paths | 数据流有影子路径 | 快乐路径只是冰山一角；nil/empty/error 路径才是线上问题的真正来源 |
| 4 | Interactions have edge cases | 交互有边界情况 | 双击提交、中途导航、慢连接——这些是用户真实会遇到的 |
| 5 | Observability is scope | 可观测性是范围，不是事后补救 | 上线后无法调试的系统比未上线的系统更糟糕 |
| 6 | Diagrams are mandatory | 图表是强制的 | ASCII 图迫使精确思考；能写出 ASCII 图才证明真正理解了数据流 |
| 7 | Everything deferred must be written down | 一切推迟都必须写下来 | 模糊的意图是谎言；TODOS.md 让推迟变得显性和可追踪 |
| 8 | Optimize for 6-month future | 为 6 个月后优化 | 解决了今天的问题但创造了下季度噩梦的方案应该被指出 |
| 9 | Permission to say "scrap it" | 有权说"推倒重来" | 这是最强的指令：如果有根本上更好的方法，现在说比以后说便宜 100 倍 |

---

## 18 个 CEO 认知模式

> **原文**：
> ```
> ## Cognitive Patterns — How Great CEOs Think
>
> These are not checklist items. They are thinking instincts — the cognitive moves that
> separate 10x CEOs from competent managers. Let them shape your perspective throughout
> the review. Don't enumerate them; internalize them.
>
> 1. Classification instinct — (Bezos) one-way/two-way doors.
> 2. Paranoid scanning — (Grove) "Only the paranoid survive."
> 3. Inversion reflex — (Munger) "What would make us fail?"
> 4. Focus as subtraction — (Jobs) 350 products → 10.
> ...
> ```

**中文**：这些不是检查清单项目。它们是思维本能——区分 10 倍效率 CEO 与胜任的经理的认知动作。不要列举它们；而是内化它们。

**完整 18 个认知模式**：

| # | 模式名 | 来源 | 核心认知动作 |
|---|-------|-----|------------|
| 1 | 分类本能 | Bezos（单向/双向门） | 可逆×影响大小 → 决策速度校准 |
| 2 | 偏执扫描 | Grove（"只有偏执狂才能生存"） | 持续扫描战略拐点、文化漂移、流程代理疾病 |
| 3 | 反转反射 | Munger | 对每个"怎么赢"，也问"什么会让我们失败" |
| 4 | 聚焦即删减 | Jobs（350 产品→10） | 主要增值是"不做什么"；默认：做更少的事，做得更好 |
| 5 | 人优先排序 | Horowitz / Hastings | 人→产品→利润；人才密度解决大多数其他问题 |
| 6 | 速度校准 | Bezos（70% 信息就够） | 快是默认；只有不可逆+高影响的决策才减速 |
| 7 | 代理怀疑 | Bezos Day 1 | 我们的指标还在服务用户，还是已经自我指涉？ |
| 8 | 叙事连贯 | 通用 | 艰难决策需要清晰框架；让"为什么"可读，不是让所有人都高兴 |
| 9 | 时间深度 | Bezos（80 岁遗憾最小化） | 以 5-10 年弧度思考；对重大赌注运用遗憾最小化 |
| 10 | 创始人模式偏向 | Chesky / Graham | 深度参与不是微管理——如果它扩展（而非约束）团队思维 |
| 11 | 战时意识 | Horowitz | 正确诊断和平时期 vs 战时；和平时期习惯杀死战时公司 |
| 12 | 勇气积累 | 通用 | 信心来自做艰难决策，而不是在之前；"挣扎就是工作" |
| 13 | 意志力作为策略 | Altman | 刻意地固执；大多数人放弃太早；世界向长期坚持的人让步 |
| 14 | 杠杆痴迷 | Altman | 找到小付出→大产出的输入点；技术是终极杠杆 |
| 15 | 层级即服务 | 通用（UI 设计） | 每个界面决策回答"用户先看什么，第二看什么，第三看什么" |
| 16 | 边界情况偏执（设计） | 通用 | 名字 47 个字符会怎样？零结果？中途网络失败？ |
| 17 | 删减默认 | Rams（尽可能少设计） | 如果 UI 元素不能挣得它的像素，删掉它 |
| 18 | 设计为信任 | 通用 | 每个界面决策要么建立要么侵蚀用户信任 |

> **设计原理：为什么是 18 个，而不是 5 个？**
> 这些认知模式不是用来逐条检查的——它们是内化的思维直觉。通过列出这么多具体的、有出处的模式，AI 在评审中会自然地调用它们：评估架构时想起反转反射，挑战范围时想起聚焦即删减，评估 UI 流程时想起层级即服务。

---

## PRE-REVIEW SYSTEM AUDIT（预评审系统审计）

> **原文**：
> ```
> Before doing anything else, run a system audit. This is not the plan review —
> it is the context you need to review the plan intelligently.
>
> git log --oneline -30
> git diff <base> --stat
> git stash list
> grep -r "TODO|FIXME|HACK|XXX" -l ...
>
> Design doc check:
> DESIGN=$(ls -t ~/.gstack/projects/$SLUG/*-$BRANCH-design-*.md 2>/dev/null | head -1)
> [ -n "$DESIGN" ] && echo "Design doc found: $DESIGN" || echo "No design doc found"
>
> If a design doc exists (from /office-hours), read it. Use it as the source of truth
> for the problem statement, constraints, and chosen approach.
> ```

**中文**：在做任何事之前，运行系统审计。这不是方案评审——这是你需要的上下文，以便智能地评审方案。

**系统审计的五个维度**：

```
┌─────────────────────────────────────────────────────────────────────┐
│                      PRE-REVIEW SYSTEM AUDIT                        │
├─────────────────────┬───────────────────────────────────────────────┤
│ git log -30         │ 最近历史：这个功能是这次全新开发还是迭代？     │
├─────────────────────┼───────────────────────────────────────────────┤
│ git diff --stat     │ 已有什么改动：防止评审内容与实际 diff 脱节     │
├─────────────────────┼───────────────────────────────────────────────┤
│ TODO/FIXME grep     │ 技术债务地图：这个方案会触碰或解锁哪些 TODO    │
├─────────────────────┼───────────────────────────────────────────────┤
│ CLAUDE.md + TODOS.md│ 项目约束和已知痛点                            │
├─────────────────────┼───────────────────────────────────────────────┤
│ /office-hours 设计文档│ 如果存在，作为问题陈述和约束的真相来源      │
└─────────────────────┴───────────────────────────────────────────────┘
```

**前置技能提供（Prerequisite Skill Offer）**：

> **原文**：
> ```
> When the design doc check prints "No design doc found," offer the prerequisite skill:
>
> "No design doc found for this branch. /office-hours produces a structured problem
> statement, premise challenge, and explored alternatives — it gives this review much
> sharper input to work with. Takes about 10 minutes."
>
> Options:
> - A) Run /office-hours now (we'll pick up the review right after)
> - B) Skip — proceed with standard review
> ```

**中文**：当没有设计文档时，主动提供 `/office-hours` 作为前置步骤。这实现了技能链的**正向嵌套**——CEO 评审可以内联执行 office-hours，完成后无缝继续评审。

> **设计原理：为什么 CEO 评审会主动调用 office-hours？**
> 没有设计文档的方案就像没有病历的手术——可以做，但风险更高。通过提供这个前置提示，gstack 将两个技能有机连接，同时不强制要求用户按固定顺序操作。

---

## Step 0: Nuclear Scope Challenge（核武器级范围挑战）

这是整个评审中最关键的阶段，在确定评审模式之前完成。

### 0A. Premise Challenge（前提假设挑战）

> **原文**：
> ```
> 1. Is this the right problem to solve? Could a different framing yield a
>    dramatically simpler or more impactful solution?
> 2. What is the actual user/business outcome? Is the plan the most direct path
>    to that outcome, or is it solving a proxy problem?
> 3. What would happen if we did nothing?
> ```

**中文**：
1. 这是正确的问题吗？不同的框架能产生更简单或更有影响力的解决方案吗？
2. 实际的用户/业务结果是什么？方案是最直接的路径，还是在解决代理问题？
3. 什么都不做会怎样？真正的痛点还是假设的？

### 0B. Existing Code Leverage（现有代码杠杆）

> **原文**：
> ```
> 1. What existing code already partially or fully solves each sub-problem?
> 2. Is this plan rebuilding anything that already exists? If yes, explain why
>    rebuilding is better than refactoring.
> ```

### 0C. Dream State Mapping（梦想状态映射）

> **原文**：
> ```
> Describe the ideal end state 12 months from now. Does this plan move toward
> that state or away from it?
>
>   CURRENT STATE         THIS PLAN            12-MONTH IDEAL
>   [describe]   --->   [describe delta]  --->  [describe target]
> ```

**中文**：这个 ASCII 三列图是强制的。它迫使评审者回答"这个方案是否在朝正确方向移动"——而不只是"这个方案技术上是否可行"。

### 0C-bis. Implementation Alternatives（实现方案备选，强制）

> **原文**：
> ```
> Before selecting a mode (0F), produce 2-3 distinct implementation approaches.
> This is NOT optional — every plan must consider alternatives.
>
> Rules:
> - At least 2 approaches required.
> - One must be the "minimal viable" (fewest files, smallest diff).
> - One must be the "ideal architecture" (best long-term trajectory).
> - Do NOT proceed to mode selection (0F) without user approval.
> ```

**三类方案（与 office-hours Phase 4 相同的结构）**：

| 方案类型 | 要求 | 哪种模式倾向于选它 |
|---------|-----|---------------|
| 最小可行方案 | 最少文件、最小 diff | SCOPE REDUCTION |
| 理想架构方案 | 最佳长期轨迹 | SCOPE EXPANSION |
| 创意/侧向方案 | 意想不到的框架 | SELECTIVE EXPANSION |

### 0D. Mode-Specific Analysis（模式特定分析）

这是四种模式在 Step 0 阶段的差异所在：

**SCOPE EXPANSION 三步仪式**：
1. **10x 检查**：2 倍工作量能带来 10 倍价值的版本是什么？具体描述。
2. **柏拉图理想**：最好的工程师有无限时间和完美品味，这个系统会是什么样？从用户体验出发，不是从架构出发。
3. **愉悦机会**：至少 5 个 30 分钟就能完成的、让用户觉得"哦，他们想到了这个"的周边改进。
4. **扩展 opt-in 仪式**：逐一通过 AskUserQuestion 提呈每个扩展提案，热情推荐，但用户决定。

**SELECTIVE EXPANSION 两步仪式**：
1. 先做 HOLD SCOPE 分析（让方案无懈可击）
2. 然后做扩展扫描（10x 检查 + 愉悦机会），以**中立姿态**逐一通过 AskUserQuestion 提呈

**HOLD SCOPE 的重点**：复杂度检查（方案触碰文件 >8 个是一个异味）+ 最小变更集识别

**SCOPE REDUCTION 的重点**：无情地切割——什么是达成核心目标的绝对最小版本？

### 0D-POST. 持久化 CEO 计划（仅 EXPANSION 和 SELECTIVE EXPANSION）

> **原文**：
> ```
> After the opt-in/cherry-pick ceremony, write the plan to disk so the vision and
> decisions survive beyond this conversation.
>
> Write to: ~/.gstack/projects/$SLUG/ceo-plans/{date}-{feature-slug}.md
>
> Content includes: Vision (10x Check + Platonic Ideal), Scope Decisions table,
> Accepted Scope list, Deferred to TODOS.md list.
> ```

**中文**：将 CEO 评审的愿景和范围决策写入磁盘。这个文件：
- 创建了跨会话的持久记忆
- 供下游技能（`/plan-eng-review`、`/plan-design-review`）读取
- 可以提升到项目仓库的 `docs/designs/` 目录（版本控制中）

### 0E. Temporal Interrogation（时间性追问，EXPANSION / SELECTIVE / HOLD 模式）

> **原文**：
> ```
>   HOUR 1 (foundations):   What does the implementer need to know?
>   HOUR 2-3 (core logic):  What ambiguities will they hit?
>   HOUR 4-5 (integration): What will surprise them?
>   HOUR 6+ (polish/tests): What will they wish they'd planned for?
>
> NOTE: With CC + gstack, 6 hours of human implementation compresses to ~30-60 minutes.
> ```

**中文**：在方案层面预判实现过程中会遇到的决策点，现在解决，而不是"边做边想"。

### 0F. Mode Selection（模式选择）

> **原文**：
> ```
> Context-dependent defaults:
> * Greenfield feature → default EXPANSION
> * Feature enhancement → default SELECTIVE EXPANSION
> * Bug fix or hotfix → default HOLD SCOPE
> * Refactor → default HOLD SCOPE
> * Plan touching >15 files → suggest REDUCTION
> * User says "go big" → EXPANSION, no question
> * User says "hold scope but tempt me" → SELECTIVE EXPANSION, no question
> ```

**中文**：情境感知的默认模式：

```
┌──────────────────────────────────────────────────────────────┐
│                    模式默认选择逻辑                            │
├──────────────────────┬───────────────────────────────────────┤
│ 全新功能（绿地）      │ EXPANSION                             │
│ 功能增强/迭代        │ SELECTIVE EXPANSION                   │
│ Bug 修复/热修复      │ HOLD SCOPE                            │
│ 重构                 │ HOLD SCOPE                            │
│ 方案触碰文件 >15 个  │ 建议 REDUCTION（除非用户反对）          │
│ 用户说 "go big"      │ EXPANSION，不用再问                   │
│ 用户说 "hold scope   │ SELECTIVE EXPANSION，不用再问          │
│         but tempt me"│                                       │
└──────────────────────┴───────────────────────────────────────┘
```

---

## 11 个评审章节（Review Sections）

> **原文**（反跳过规则）：
> ```
> Anti-skip rule: Never condense, abbreviate, or skip any review section (1-11)
> regardless of plan type. Every section exists for a reason.
> "This is a strategy doc so implementation sections don't apply" is always wrong —
> implementation details are where strategy breaks down. If a section genuinely has
> zero findings, say "No issues found" and move on — but you must evaluate it.
> ```

**中文**：永远不要压缩、缩写或跳过任何评审章节（1-11），无论方案类型如何。每个章节都有存在的原因。"这是策略文档所以实现章节不适用"——这永远是错的。实现细节正是策略崩溃的地方。

**11 个章节总览**：

```
┌─────────────────────────────────────────────────────────────────────┐
│                   11 个评审章节                                       │
├────┬──────────────────┬─────────────────────────────────────────────┤
│ 1  │ Architecture     │ 系统设计、数据流四路径、状态机、耦合、扩展性  │
│ 2  │ Error & Rescue   │ 每个可失败的方法/服务的完整异常映射表         │
│ 3  │ Security         │ 攻击面扩展、输入验证、授权、注入向量          │
│ 4  │ Data Flow & UX   │ 数据流追踪（含影子路径）+ 交互边界情况        │
│ 5  │ Code Quality     │ DRY 违规、命名质量、过度/不足工程化           │
│ 6  │ Test Review      │ 完整测试图、测试类型、测试雄心检查            │
│ 7  │ Performance      │ N+1 查询、内存、DB 索引、缓存、连接池         │
│ 8  │ Observability    │ 日志、指标、追踪、告警、仪表板、runbook       │
│ 9  │ Deployment       │ 迁移安全、特性标志、回滚计划、部署顺序        │
│ 10 │ Long-Term        │ 技术债务、路径依赖、知识集中、可逆性          │
│ 11 │ Design & UX      │ 信息架构、交互状态覆盖图（仅有 UI 范围时）    │
└────┴──────────────────┴─────────────────────────────────────────────┘
```

### Section 2 深度解析：Error & Rescue Map

这是最容易被忽视、也最有价值的章节之一：

> **原文**：
> ```
>   METHOD/CODEPATH      | WHAT CAN GO WRONG    | EXCEPTION CLASS
>   ---------------------|----------------------|------------------
>   ExampleService#call  | API timeout          | TimeoutError
>                        | API returns 429      | RateLimitError
>
>   EXCEPTION CLASS      | RESCUED? | RESCUE ACTION    | USER SEES
>   ---------------------|----------|------------------|----------------
>   TimeoutError         | Y        | Retry 2x, raise  | "Temporarily unavailable"
>   JSONParseError       | N ← GAP  | —                | 500 error ← BAD
>
> Rules:
> - Catch-all error handling (rescue StandardError, except Exception) is ALWAYS a smell.
> - For LLM/AI service calls: what happens when response is malformed? Empty? Hallucinates?
>   Model returns a refusal? Each is a distinct failure mode.
> ```

**中文**：填写一张完整的异常映射表。`RESCUED=N` 且 `USER SEES=Silent` 的行 → **CRITICAL GAP（关键缺口）**。

> **设计原理**：LLM 特有的失败模式
> 注意原文专门提到了 LLM/AI 服务调用的失败模式——这是 2024-2025 年新增的覆盖点。JSON 格式错误、空响应、幻觉出无效 JSON、模型拒绝——每种都是独立的失败模式，需要独立处理。

### Section 6 深度解析：Test Review 的"测试雄心检查"

> **原文**：
> ```
> Test ambition check (all modes): For each new feature, answer:
> * What's the test that would make you confident shipping at 2am on a Friday?
> * What's the test a hostile QA engineer would write to break this?
> * What's the chaos test?
> ```

**中文**：三个标准性问题：
1. 什么测试能让你有信心在周五凌晨 2 点发布？
2. 一个充满敌意的 QA 工程师会写什么测试来破坏这个？
3. 混沌测试是什么？

---

## Outside Voice（外部声音——独立计划挑战）

> **原文**：
> ```
> After all review sections are complete, offer an independent second opinion.
> Two models agreeing on a plan is stronger signal than one model's thorough review.
>
> Construct prompt with filesystem boundary instruction (prevents reading skill files):
> "IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/,
> .claude/skills/, or agents/..."
>
> codex exec "<prompt>" -C "$_REPO_ROOT" -s read-only -c 'model_reasoning_effort="high"'
>
> Cross-model tension: Flag where outside voice disagrees with review findings.
> User Sovereignty: Do NOT auto-incorporate recommendations. Present each via
> AskUserQuestion. Cross-model consensus is a strong signal — but the user decides.
> ```

**中文**：11 个章节完成后，提供第二个独立 AI 视角——它没有看过这次评审对话，只收到方案内容。

**外部声音流程**：

```
11 个评审章节完成
        │
        ▼
  AskUserQuestion:
  "要一个外部声音吗？"
        │
   A) 是 │ B) 否
        │
        ▼
  CODEX 可用？
   是 │  否
      │    └──→ Claude 子代理（全新上下文）
      ▼
  codex exec
  (read-only, high reasoning,
   5 分钟超时)
        │
        ▼
  逐字展示输出
  ═══════════════════════
  CODEX SAYS:
  ═══════════════════════
        │
        ▼
  CROSS-MODEL TENSION:
  发现不一致点
        │
        ▼
  对每个分歧点 AskUserQuestion
  （绝不自动采纳）
```

> **设计原理：用户主权（User Sovereignty）**
> 这是 gstack 哲学的核心：即使两个 AI 模型都同意某个变更，同意也只是建议，不是许可。"跨模型共识是强信号——呈现它——但用户做决定。"这防止了 AI 越权代劳的风险。

---

## 必要输出（Required Outputs）

评审结束时必须产生的产物：

| 产物 | 内容 |
|-----|-----|
| "NOT in scope" 章节 | 考虑过但明确推迟的工作，每项一行理由 |
| "What already exists" 章节 | 现有代码/流程中已部分解决子问题的部分 |
| "Dream state delta" 章节 | 这个方案执行后，离 12 个月理想状态还差多远 |
| Error & Rescue Registry | 完整的方法/异常/处理状态/用户影响表 |
| Failure Modes Registry | `RESCUED=N, TEST=N, USER SEES=Silent` 的行 = CRITICAL GAP |
| Diagrams（6 种） | 系统架构、数据流（含影子路径）、状态机、错误流、部署序列、回滚流程图 |
| TODOS.md 更新 | 每个 TODO 单独一个 AskUserQuestion，绝不批量 |
| Completion Summary | ASCII 格式的完整评审汇总表 |

**Completion Summary 格式**：

```
+====================================================================+
|            MEGA PLAN REVIEW — COMPLETION SUMMARY                   |
+====================================================================+
| Mode selected        | EXPANSION / SELECTIVE / HOLD / REDUCTION     |
| Section 1  (Arch)    | ___ issues found                            |
| Section 2  (Errors)  | ___ error paths mapped, ___ GAPS            |
| Section 3  (Security)| ___ issues found, ___ High severity         |
| Section 4  (Data/UX) | ___ edge cases mapped, ___ unhandled        |
| Section 5  (Quality) | ___ issues found                            |
| Section 6  (Tests)   | Diagram produced, ___ gaps                  |
| Section 7  (Perf)    | ___ issues found                            |
| Section 8  (Observ)  | ___ gaps found                              |
| Section 9  (Deploy)  | ___ risks flagged                           |
| Section 10 (Future)  | Reversibility: _/5, debt items: ___         |
| Section 11 (Design)  | ___ issues / SKIPPED (no UI scope)          |
+--------------------------------------------------------------------+
| Lake Score           | X/Y recommendations chose complete option   |
| Unresolved decisions | ___ (listed below)                          |
+====================================================================+
```

---

## Review Readiness Dashboard（评审就绪仪表板）

> **原文**：
> ```
> +====================================================================+
> |                    REVIEW READINESS DASHBOARD                       |
> +====================================================================+
> | Review          | Runs | Last Run            | Status    | Required |
> |-----------------|------|---------------------|-----------|----------|
> | Eng Review      |  1   | 2026-03-16 15:00    | CLEAR     | YES      |
> | CEO Review      |  0   | —                   | —         | no       |
> | Design Review   |  0   | —                   | —         | no       |
> | Adversarial     |  0   | —                   | —         | no       |
> | Outside Voice   |  0   | —                   | —         | no       |
> +--------------------------------------------------------------------+
> | VERDICT: CLEARED — Eng Review passed                                |
> +====================================================================+
>
> Review tiers:
> - Eng Review (required by default): The ONLY review that gates shipping.
> - CEO Review (optional): Recommend for big product/business changes.
> - Design Review (optional): Recommend for UI/UX changes.
> - Adversarial Review (automatic): Always-on for every review.
> - Outside Voice (optional): Never gates shipping.
> ```

**中文**：评审就绪状态的仪表板，显示每种评审的运行次数、最近运行时间和状态。

**评审层级**：

| 评审类型 | 是否必须 | 何时推荐 | 封锁发布？ |
|---------|---------|---------|---------|
| Eng Review | **默认必须** | 总是 | **是** |
| CEO Review | 可选 | 重大产品/业务变更，新用户功能 | 否 |
| Design Review | 可选 | UI/UX 变更 | 否 |
| Adversarial Review | **自动** | 每次评审都运行 | 否 |
| Outside Voice | 可选 | CEO 评审和 Eng 评审完成后 | 否 |

**过期检测**：通过比较评审时的 commit hash 与当前 HEAD，如果两者不同，报告自评审以来有多少次提交，提示可能需要重新评审。

---

## 在技能链中的位置

```
┌─────────────────────────────────────────────────────────────────────┐
│  用户有一个方案，问："够大胆吗？" / "这值得扩展吗？"                  │
└──────────────────────┬──────────────────────────────────────────────┘
                       │
                       ▼
          /office-hours（如果还没做过）
          ──────────────────────────
          输出：设计文档 → plan-ceo-review 读取
                       │
                       ▼
          /plan-ceo-review  ← 你在这里
          ─────────────────
          职责：策略层 + 范围决策 + 10x 愿景
          输出：CEO 计划文档（~/.gstack/projects/$SLUG/ceo-plans/）
                       │
          ┌────────────┴────────────┐
          │                        │
          ▼                        ▼
  /plan-eng-review        /plan-design-review
  "怎样建得更稳？"         "UI/UX 是否够好？"
  （架构层，必须）          （设计层，可选）
          │                        │
          └────────────┬───────────┘
                       │
                       ▼
                    /ship
                   "发出去"
```

---

## 整体设计核心思路汇总表

| 机制 | 设计决策 | 背后原因 |
|-----|---------|---------|
| **四种模式** | EXPANSION / SELECTIVE / HOLD / REDUCTION | 不同情境需要根本不同的姿态，一刀切会错误地扩大或缩小范围 |
| **模式承诺刚性** | 选定后不能漂移 | 防止在讨论具体问题时无意识地背离最初立场 |
| **完整性很便宜** | AI 时代默认选完整方案 | 70 行代码差距在 CC 下只需 5 分钟，"Ship the shortcut" 是过时思维 |
| **9 条 Prime Directives** | 包括"有权说推倒重来" | 明确赋予 AI 指出根本性问题的权力，而不只是修修补补 |
| **18 个认知模式** | 来自 Bezos/Grove/Munger/Jobs/Horowitz 等 | 将最优秀 CEO 的思维本能编码为 AI 的评审直觉 |
| **系统审计前置** | 评审前必先做系统审计 | 没有上下文的评审是危险的；了解现状才能评估变化的影响 |
| **与 office-hours 无缝嵌套** | 可内联调用 office-hours | 用户可以任意顺序进入工作流，系统会引导他们完善缺失的前置步骤 |
| **11 个评审章节（反跳过规则）** | 每个章节都必须评估，无论方案类型 | 策略文档的实现细节章节通常正是策略崩溃的地方 |
| **Error Map 是独立章节** | 第 2 章，而不是第 1 章的子章节 | 强调异常映射的地位——它不是架构的附属品，是独立的关键输出 |
| **外部声音 + 用户主权** | 提供但不自动采纳 | 跨模型共识是信号，不是指令；决策权始终在人类 |
| **CEO 计划持久化** | 写入 `~/.gstack/projects/` | 跨会话、跨技能的愿景记忆；可提升到版本控制 |
| **评审就绪仪表板** | 机器可读的评审状态 | `/ship` 在发布时会检查这个仪表板；CEO 评审标记自己，不需要人工追踪 |
| **Eng Review 是唯一必须项** | 其他评审不封锁发布 | 工程质量是非协商的底线；策略/设计评审是锦上添花 |
| **TODOS.md 一次一个 AskUserQuestion** | 绝不批量 | 每个 TODO 都需要独立的商业理由；批量 TODO 是将未思考的工作推给未来 |
