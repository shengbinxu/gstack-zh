# `/plan-eng-review` 技能深度注解

> 对应源文件：`plan-eng-review/SKILL.md.tmpl`（317 行）
> 本文在原文结构基础上加入中文翻译、设计原理解读，以及适合中国开发者的背景说明。

---

## 这个技能是什么？

`/plan-eng-review` 是 gstack 的"工程经理评审"技能。

**触发时机**：你有一个设计方案/技术方案，准备开始写代码之前。

**它做什么**：
- 以工程经理（Eng Manager）视角，系统性地检查你的技术方案
- 发现架构缺陷、测试盲点、性能问题
- 每发现一个问题就暂停，用 AskUserQuestion 和你讨论
- 最后输出完整的评审报告 + 可视化测试覆盖图

**不做什么**：不写代码，只评审。

---

## Frontmatter（元数据）解读

```yaml
---
name: plan-eng-review
preamble-tier: 3      # preamble 详细度级别（3 = 最完整）
version: 1.0.0
description: |
  Eng manager-mode plan review. Lock in the execution plan — architecture,
  data flow, diagrams, edge cases, test coverage, performance.
voice-triggers:        # 语音触发词：说这些词会自动激活此技能
  - "tech review"
  - "technical review"
  - "plan engineering review"
benefits-from: [office-hours]   # 建议先跑 office-hours 再跑这个
allowed-tools:                  # 只允许使用这些工具
  - Read
  - Write
  - Grep
  - Glob
  - AskUserQuestion
  - Bash
  - WebSearch
---
```

**设计原理：为什么限制 allowed-tools？**

`plan-eng-review` 不允许使用 `Edit`（代码修改工具）。这是刻意的：
- 评审阶段只能读取、分析、提问
- 防止 Claude 在你还没确认方向时就开始改代码
- "先锁定方案，再动代码"——这是严肃的工程实践

**preamble-tier: 3 是什么意思？**

gstack 有 3 级 preamble（前置准备步骤）：
- Tier 1：最简，只做基础检查
- Tier 2：中等，包含学习记录搜索
- Tier 3：最完整，包含学习记录 + 信心校准 + Codex 外部意见

评审技能用最高级，确保上下文最完整。

---

## 核心流程图

```
用户说 /plan-eng-review
         │
         ▼
┌─────────────────────────────────┐
│  BEFORE YOU START               │
│  1. 搜索设计文档 (~/.gstack/)   │
│  2. 读取 benefits-from 历史      │
│  3. 搜索历史 learnings          │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Step 0: Scope Challenge        │  ← 先砍范围，再评审
│  - 现有代码已解决了哪些子问题？  │
│  - 最小变更集是什么？           │
│  - 复杂度警戒：>8个文件触发警告  │
│  - 搜索：有没有内置方案？        │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  四轮评审（每轮结束必须停下来）   │
│                                 │
│  1. Architecture Review         │
│     └→ AskUserQuestion (每个问题单独问)
│                                 │
│  2. Code Quality Review         │
│     └→ AskUserQuestion (每个问题单独问)
│                                 │
│  3. Test Review                 │
│     └→ 生成测试覆盖图            │
│     └→ AskUserQuestion           │
│                                 │
│  4. Performance Review          │
│     └→ AskUserQuestion           │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Required Outputs               │
│  - NOT in scope 区              │
│  - What already exists 区       │
│  - TODOS.md 更新建议            │
│  - 故障模式（Failure modes）    │
│  - 并行化策略（Worktree lanes） │
│  - 完成摘要                     │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Review Log                     │
│  写入 ~/.gstack/reviews/        │  ← /ship 评审看板依赖此数据
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Review Chaining                │
│  建议后续：设计评审？CEO评审？  │
│  还是直接去 /ship？              │
└─────────────────────────────────┘
```

---

## 工程偏好声明（Engineering Preferences）

```
## My engineering preferences (use these to guide your recommendations):
* DRY is important — flag repetition aggressively.
* Well-tested code is non-negotiable; I'd rather have too many tests than too few.
* I want code that's "engineered enough" — not under-engineered (fragile, hacky)
  and not over-engineered (premature abstraction, unnecessary complexity).
* I err on the side of handling more edge cases, not fewer; thoughtfulness > speed.
* Bias toward explicit over clever.
* Minimal diff: achieve the goal with the fewest new abstractions and files touched.
```

**中文解读：**

| 偏好 | 含义 | 实际影响 |
|------|------|---------|
| DRY 优先 | Don't Repeat Yourself | AI 会主动指出重复代码 |
| 测试不可妥协 | 宁多勿少 | 评审时会严查测试覆盖 |
| "恰好够工程化" | 不糙、不过度设计 | 拒绝提前抽象，也拒绝临时代码 |
| 处理更多边界情况 | 思考 > 速度 | AI 会主动问"如果 X 发生怎么办" |
| 显式优于聪明 | explicit > clever | 拒绝炫技式代码 |
| 最小 diff | 最少改动达成目标 | 不会因为"顺手"就重构 |

**这些偏好是 Garry Tan 个人的工程风格**，被硬编码进了每次评审的上下文。
这让 AI 不是泛泛地"评审代码"，而是按照特定工程哲学来评审。

---

## 15 个认知模式（Cognitive Patterns）

这是整个技能里最有学术含量的部分。这些不是检查列表，而是优秀工程管理者的思维惯式。

```
## Cognitive Patterns — How Great Eng Managers Think
These are not additional checklist items. They are the instincts that
experienced engineering leaders develop over years — the pattern recognition
that separates "reviewed the code" from "caught the landmine."
```

**中文：** 这些不是额外的清单项。它们是优秀工程 leader 多年积累的本能——
区分"我审了代码"和"我抓住了地雷"的模式识别能力。

### 逐条解读

| # | 模式 | 来源 | 核心思想 |
|---|------|------|---------|
| 1 | **状态诊断** | Larson《An Elegant Puzzle》 | 团队处于4种状态之一：落后/踩水/还债/创新，不同状态需要不同干预 |
| 2 | **爆炸半径本能** | 通用 | 每个决定都问："最坏情况影响几个系统/几个人？" |
| 3 | **默认无聊** | McKinley《选择无聊的技术》 | 每个公司有约3个"创新代币"，其余用成熟技术 |
| 4 | **渐进优于革命** | Fowler 重构理论 | 勒死法（Strangler Fig）而非大爆炸；灰度发布而非全量 |
| 5 | **系统优于英雄** | SRE 思想 | 为凌晨3点疲惫的普通人设计，不是为状态最好的顶级工程师 |
| 6 | **可逆性偏好** | 通用 | Feature flag、A/B 测试、增量发布——让犯错成本低 |
| 7 | **故障即信息** | Allspaw / Google SRE | 无惩罚事后复盘，error budget，混沌工程 |
| 8 | **组织结构即架构** | Conway 定律 + Team Topologies | 系统架构 = 沟通结构，两者要有意识地协同设计 |
| 9 | **开发者体验即产品质量** | 通用 | CI 慢 → 软件质量差 → 人员流失 |
| 10 | **本质 vs 偶然复杂度** | Brooks《没有银弹》 | 每次加东西前问："这解决的是真实问题还是我们自造的问题？" |
| 11 | **两周气味测试** | 通用 | 普通工程师两周内无法上手新功能 → 这是架构问题，不是人的问题 |
| 12 | **胶水工作意识** | Reilly《Staff Engineer之道》 | 识别无形的协调工作，重视它，但别让人只做它 |
| 13 | **先易改，再做改** | Beck | 先重构结构，再改行为。永远不要同时做两件事 |
| 14 | **在生产中拥有你的代码** | Majors | 没有开发与运维的墙。工程师写代码，也在生产中拥有它 |
| 15 | **Error budget 优于可用率目标** | Google SRE | 99.9% SLO = 0.1% 的宕机预算，可以用来发货 |

**为什么把这些嵌进 prompt？**

纯粹的清单容易变成机械检查。把思维模式嵌进上下文，让 AI 能做出更像
有经验工程师的判断——比如在评审测试覆盖时想到"系统优于英雄"，
在评审新基础设施时想到"创新代币还剩几个"。

---

## Step 0：范围挑战（Scope Challenge）

这是整个评审里最重要的一步，放在最前面。

```
### Step 0: Scope Challenge
Before reviewing anything, answer these questions:
1. What existing code already partially or fully solves each sub-problem?
2. What is the minimum set of changes that achieves the stated goal?
3. Complexity check: If the plan touches more than 8 files or introduces
   more than 2 new classes/services, treat that as a smell...
4. Search check: For each architectural pattern, infrastructure component...
5. Completeness check: Is the plan doing the complete version or a shortcut?
6. Distribution check: If the plan introduces a new artifact type...
```

**中文：**
在评审任何东西之前，先回答这些问题：
1. 现有代码已经部分或完全解决了哪些子问题？
2. 达成目标所需的最小变更集是什么？
3. 复杂度检查：方案涉及超过 8 个文件或引入超过 2 个新类/服务 → 发出警告
4. 搜索检查：每个架构模式或基础设施组件，有没有内置方案？
5. 完整性检查：方案是做完整版还是走捷径？
6. 分发检查：如果引入新产物类型（CLI 二进制、库包等），有没有构建/发布管道？

**设计原理：为什么先砍范围？**

```
复杂度警戒阈值：
  > 8 个文件  → 气味出现，主动挑战范围
  > 2 个新类  → 同上

如果触发：
  用 AskUserQuestion 问：
  "解释哪里过度设计了"
  "提出一个达到核心目标的精简版本"
  "问用户是精简还是按原计划走"
```

gstack 的哲学：AI 让"做完整的事"几乎免费（时间压缩 30-100x），
但这不等于"做所有事"——范围膨胀是杀死项目的最常见原因。
所以 Step 0 的存在是为了先砍掉不必要的范围，再在剩余范围内做完整。

**搜索检查的三层注解（Layer 1/2/3）**

```
Annotate recommendations with [Layer 1], [Layer 2], [Layer 3], or [EUREKA]
(see preamble's Search Before Building section).
```

这来自 ETHOS.md 的"Search Before Building"哲学：
- **Layer 1**（久经考验）：用成熟库/内置功能，不要重造
- **Layer 2**（新且流行）：谨慎审查，可能有未知 footgun
- **Layer 3**（从第一原理出发）：最珍贵，当 Layer 1/2 都不适合时的原创方案
- **EUREKA**：发现标准方案在这个特定场景下是错的——这是架构洞察

---

## 四轮评审结构

```
## Review Sections (after scope is agreed)

**Anti-skip rule:** Never condense, abbreviate, or skip any review section
(1-4) regardless of plan type (strategy, spec, code, infra).
```

**Anti-skip rule（禁止跳过规则）的必要性：**

"这是策略文档，所以实现细节部分不适用"——这种理由永远是错的。
实现细节正是策略崩溃的地方。即使某个部分真的没有发现，也要写"No issues found"。

```
                 ┌──────────────────────┐
                 │  1. Architecture     │
                 │     系统设计          │
                 │     依赖关系          │
                 │     数据流            │
                 │     扩展性            │
                 │     安全架构          │
                 │     分发架构          │
                 └──────────┬───────────┘
                            │ STOP → AskUserQuestion（逐个问题）
                 ┌──────────▼───────────┐
                 │  2. Code Quality     │
                 │     代码组织          │
                 │     DRY 违规         │
                 │     错误处理          │
                 │     技术债热点        │
                 │     ASCII 图是否过期  │
                 └──────────┬───────────┘
                            │ STOP → AskUserQuestion（逐个问题）
                 ┌──────────▼───────────┐
                 │  3. Test Review      │
                 │     覆盖率            │
                 │     测试覆盖图        │
                 │     LLM/Prompt 变更  │
                 └──────────┬───────────┘
                            │ STOP → AskUserQuestion（逐个问题）
                 ┌──────────▼───────────┐
                 │  4. Performance      │
                 │     N+1 查询          │
                 │     内存              │
                 │     缓存机会          │
                 │     高复杂度路径      │
                 └──────────────────────┘
```

**STOP 规则的核心设计思想：**

```
**STOP.** For each issue found in this section, call AskUserQuestion individually.
One issue per call. Do NOT batch multiple issues into one AskUserQuestion.
```

为什么"一个问题一次询问"？

批量询问的问题：
- 用户容易只回答第一个，忽略其余
- 多个问题混合后决策质量下降
- 无法记录哪个问题选了哪个方案

独立询问的好处：
- 强制 AI 和用户对每个问题都做出明确决策
- 决策链可追溯
- 可以中途改变某一个问题的决策而不影响其他问题

---

## AskUserQuestion 格式规范

```
## CRITICAL RULE — How to ask questions
* One issue = one AskUserQuestion call.
* Describe the problem concretely, with file and line references.
* Present 2-3 options, including "do nothing" where that's reasonable.
* For each option, specify: effort (human: ~X / CC: ~Y), risk, maintenance burden.
* Map the reasoning to my engineering preferences above.
* Label with issue NUMBER + option LETTER (e.g., "3A", "3B").
```

**格式解读（以一个真实问题为例）：**

```
问题 #2：auth.ts:47 的令牌检查在会话过期时返回 undefined

这会在 20% 的用户请求中触发静默失败（无报错，直接返回 null）。

2A) 添加显式检查 + 抛出 AuthExpiredError
    - 努力：human: ~2h / CC: ~5min
    - 风险：低（只改错误路径）
    - 维护：标准异常，无额外负担
    - [对应偏好：explicit > clever]

2B) 重构会话管理，统一处理令牌生命周期
    - 努力：human: ~1d / CC: ~20min
    - 风险：中（触碰核心流程）
    - 维护：更清晰的长期架构
    - [对应偏好：DRY + engineered enough]

2C) 不处理——调用方已有保护逻辑
    - 努力：0
    - 风险：高（现有保护是否完整未经验证）
    - 维护：0

推荐：2A（完成版是 lake，不是 ocean；CC 只需 5 分钟）
```

**effort 标注的含义：`human: ~X / CC: ~Y`**

这是 gstack 的"AI 压缩比"概念。gstack 的核心主张之一：
AI 让许多任务的成本下降 20-100x。在推荐选项时，要给出两种时间估算，
让用户看到"做完整的事"在 CC+gstack 下其实并不贵。

---

## Required Outputs（必须输出）

### NOT in scope 区

```
### "NOT in scope" section
Every plan review MUST produce a "NOT in scope" section listing work that was
considered and explicitly deferred, with a one-line rationale for each item.
```

这是强制的。为什么？
- 让"我们考虑过 X，但决定不做"变成明确的记录
- 防止以后有人问"为什么没做 X"时无法回答
- 下次评审时可以检查是否是时候从 NOT in scope 里取出来做

### Worktree 并行化策略

```
### Worktree parallelization strategy
Analyze the plan's implementation steps for parallel execution opportunities.
```

这是 gstack 独有的输出，利用 Claude Code 的 Agent 工具 + git worktree：

```
Lane A: 后端 API 实现 → 集成测试
    ↓（无依赖关系）
Lane B: 前端 UI 组件 → 单元测试

Lane C: 部署配置（依赖 A+B 合并）

执行：
  并行启动 Lane A + Lane B（各自在独立 worktree）
  两者合并后再启动 Lane C
```

**现实价值：** 一个人用两个 Claude Code 窗口，同时推进两条独立开发线，
最后合并。这在传统开发里需要一个小团队协作。

### Failure Modes（故障模式）

```
### Failure modes
For each new codepath, list one realistic way it could fail in production
(timeout, nil reference, race condition, stale data, etc.) and whether:
1. A test covers that failure
2. Error handling exists for it
3. The user would see a clear error or a silent failure

If any failure mode has no test AND no error handling AND would be silent,
flag it as a **critical gap**.
```

**Critical gap（关键缺口）** 的严重性：没有测试 + 没有错误处理 + 用户看不到错误信息 = 最危险的组合。
数据静默丢失、事务静默回滚、请求静默超时——这些在生产环境里最难排查。

---

## Review Log 和 Review Dashboard

```
## Review Log
~/.claude/skills/gstack/bin/gstack-review-log '{"skill":"plan-eng-review",...}'
```

这条命令把评审结果写入 `~/.gstack/reviews/review-log.jsonl`。

**为什么这很重要？**

`/ship` 技能在发布前会检查这个文件，显示一个"评审就绪看板"：

```
Review Readiness Dashboard
──────────────────────────
✅ plan-eng-review  — clean, 0 critical gaps    (commit abc123, 2h ago)
⚠️  plan-design-review — issues_open            (commit def456, 3d ago)
─  plan-ceo-review  — not run

VERDICT: READY TO SHIP (eng review clean)
```

如果工程评审有未解决问题，`/ship` 会发出警告，让你在发布前再想想。

---

## Review Chaining（评审链）

```
## Next Steps — Review Chaining
After displaying the Review Readiness Dashboard, check if additional reviews
would be valuable.

Suggest /plan-design-review if UI changes exist...
Mention /plan-ceo-review if this is a significant product change...
```

`/plan-eng-review` 不是孤立存在的，它是评审链的一环：

```
/office-hours         （产品方向：这值得做吗？）
      │
      ▼
/plan-ceo-review      （CEO 视角：范围、风险、用户价值）
      │
      ▼
/plan-eng-review  ← 你在这里（架构、测试、性能）
      │
      ▼
/plan-design-review   （UI/UX 一致性）
      │
      ▼
/ship                 （发布：PR 评审 + 部署）
```

每个评审都可以单独运行，也可以按链路顺序全跑。
`/autoplan` 技能可以自动触发全链路。

---

## 在 gstack 项目里的特殊行为

这个技能在 gstack 开发环境里有两个特殊上下文：

1. **{{CODEX_PLAN_REVIEW}}** 变量：如果安装了 OpenAI Codex CLI，会同时请求 Codex 对方案的意见，
   作为"外部声音"（outside voice）。但外部声音只是信息，必须用 AskUserQuestion 让用户明确批准才能采纳。

2. **{{TEST_COVERAGE_AUDIT_PLAN}}** 变量：生成测试覆盖图，可视化每个功能路径对应的测试用例。
   这是 gstack 测试三层体系（Layer 1: 静态验证 / Layer 2: 端到端 / Layer 3: LLM 评判）的具体应用。

---

## 总结：设计核心思路

| 设计决策 | 原因 |
|---------|------|
| STOP 规则（每个问题单独问） | 强制决策可追溯，防止用户跳过 |
| 禁止 Edit 工具 | 评审不是实现，先锁定方案 |
| Step 0 在最前 | 先控制范围，避免评审过度设计的方案 |
| 15 个认知模式嵌入上下文 | 让 AI 做出像有经验工程师的判断 |
| Review Log 写入持久存储 | /ship 看板依赖历史评审数据 |
| Worktree 并行化策略 | 将一人项目的工作流扩展为"虚拟团队并行" |
| Failure Modes + critical gap | 主动发现"无测试+无错误处理+静默失败"的最危险组合 |

这个技能是 gstack 的核心——Garry Tan 把他多年工程管理经验
压缩进了 317 行 prompt 模板。它不是"帮你写代码"，而是
"帮你在写代码之前把方案想清楚"。
