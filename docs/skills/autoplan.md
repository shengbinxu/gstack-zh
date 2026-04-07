# `/autoplan` 技能逐段中英对照注解

> 对应源文件：[`autoplan/SKILL.md`](https://github.com/garrytan/gstack/blob/main/autoplan/SKILL.md)（1465 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: autoplan
preamble-tier: 3
version: 1.0.0
description: |
  Auto-review pipeline — reads the full CEO, design, eng, and DX review skills from disk
  and runs them sequentially with auto-decisions using 6 decision principles. Surfaces
  taste decisions (close approaches, borderline scope, codex disagreements) at a final
  approval gate. One command, fully reviewed plan out.
benefits-from: [office-hours]
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - WebSearch
  - AskUserQuestion
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/autoplan` 触发。也接受语音别名 "auto plan"、"automatic review"。
- **preamble-tier: 3**: Preamble 详细度级别 3，包含完整的 repo 模式检测、上下文恢复、遥测等前置逻辑。
- **description**: 自动评审流水线——从磁盘读取 CEO、设计、工程、DX 四个评审技能的完整文件，使用 6 条决策原则顺序自动决策。品味决策（合理分歧）在最终批准门关呈现给用户。一条命令，全流程评审完毕。
- **benefits-from: [office-hours]**: 建议先运行 `/office-hours`。如有设计文档会自动读取，让评审有更清晰的输入。
- **allowed-tools**: 包含 **Edit**（需要写方案文件）和全套工具，比只读评审技能权限更高。

> **设计原理：为什么有 Edit 权限？**
> `/autoplan` 需要在整个流程中持续向方案文件写入审计日志、各阶段产出物、最终评审报告。Edit 是必须的——评审过程本身就是方案的一部分。

---

## {{PREAMBLE}} 展开区

原文的 Preamble 部分是标准的 gstack tier-3 前置脚本，在运行时展开为约 400 行的前置逻辑。它的作用分几个层次：

1. **环境初始化**：检查 gstack 版本更新、创建会话标记文件、检测当前分支、读取配置（proactive 模式、技能前缀、遥测设置）、检测 repo 模式（solo/collaborative）
2. **Boil the Lake 原则**：首次运行时介绍 gstack 核心哲学——AI 让完整性变得廉价，不要走捷径
3. **遥测询问（一次性）**：询问是否分享匿名使用数据（community / anonymous / off 三档）
4. **主动模式询问（一次性）**：是否允许 gstack 主动建议技能
5. **CLAUDE.md 路由注入（每项目一次）**：是否在项目 CLAUDE.md 添加技能路由规则
6. **Vendoring 弃用检测**：如果项目中存在 gstack 的本地副本（vendored），提示迁移到 team mode
7. **Spawned Session 检测**：如果在 OpenClaw 等 AI 编排器内运行，跳过所有交互提示，自动选择推荐选项

> **设计原理：Spawned Session 例外**
> 当 `/autoplan` 被 AI 编排器（如 OpenClaw）自动调用时，所有 AskUserQuestion 都无法交互。所以检测到 `SPAWNED_SESSION=true` 时，自动选推荐选项，最终输出完成报告而非等待用户输入。

---

## 原文核心段：流水线总入口

> **原文**：
> ```
> # /autoplan — Auto-Review Pipeline
>
> One command. Rough plan in, fully reviewed plan out.
>
> /autoplan reads the full CEO, design, eng, and DX review skill files from disk and follows
> them at full depth — same rigor, same sections, same methodology as running each skill
> manually. The only difference: intermediate AskUserQuestion calls are auto-decided using
> the 6 principles below. Taste decisions (where reasonable people could disagree) are
> surfaced at a final approval gate.
> ```

**中文**：一条命令。粗糙方案进，全面评审完的方案出。

`/autoplan` 从磁盘读取 CEO、设计、工程、DX 评审技能的完整文件，按完整深度执行——和手动运行每个技能的严格程度、章节、方法论完全相同。唯一的区别：中间的 AskUserQuestion 调用使用下面的 6 条原则自动决定。品味决策（合理分歧的地方）在最终批准门关呈现。

> **设计原理：核心价值主张**
> 没有 `/autoplan` 之前，跑完 4 个评审要回答 15-30 个中间问题，整个过程需要持续陪跑。有了 `/autoplan`，用户只需：(1) 启动，(2) 确认前提假设，(3) 在最终门关审核品味决策。中间全部自动化。

---

## 6 条决策原则

> **原文**：
> ```
> ## The 6 Decision Principles
>
> 1. Choose completeness — Ship the whole thing. Pick the approach that covers more edge cases.
> 2. Boil lakes — Fix everything in the blast radius. Auto-approve expansions that are in
>    blast radius AND < 1 day CC effort.
> 3. Pragmatic — If two options fix the same thing, pick the cleaner one.
> 4. DRY — Duplicates existing functionality? Reject. Reuse what exists.
> 5. Explicit over clever — 10-line obvious fix > 200-line abstraction.
> 6. Bias toward action — Merge > review cycles > stale deliberation.
>
> Conflict resolution (context-dependent tiebreakers):
> - CEO phase: P1 (completeness) + P2 (boil lakes) dominate.
> - Eng phase: P5 (explicit) + P3 (pragmatic) dominate.
> - Design phase: P5 (explicit) + P1 (completeness) dominate.
> ```

**中文**：

| 原则编号 | 名称 | 行为 |
|---------|------|------|
| P1 | 选完整性 | 选覆盖更多边界情况的方案 |
| P2 | 清空湖底 | 修爆炸半径内的所有东西，CC 努力 < 1 天就自动批准 |
| P3 | 务实 | 两个方案修同样问题？选更干净的那个 |
| P4 | DRY | 重复已有功能？拒绝，复用已有代码 |
| P5 | 显式优于聪明 | 10 行明显的修复 > 200 行抽象 |
| P6 | 偏向行动 | 合并 > 评审循环 > 停滞审议 |

**按阶段的冲突解决**：

| 评审阶段 | 主导原则 | 原因 |
|---------|---------|------|
| CEO 阶段 | P1 + P2 | 战略层要求完整，扩大范围的价值最高 |
| Eng 阶段 | P5 + P3 | 工程要求清晰可读，不要过度工程化 |
| Design 阶段 | P5 + P1 | 设计要明确指定，不留实现空白 |

> **设计原理：为什么原则因阶段而异？**
> CEO 评审关注战略完整性，"做全"比"做简单"更重要。工程评审关注可维护性，过度抽象是风险。设计评审两者都要：UI 状态要完整（P1），但每个状态的描述要明确具体（P5）。同一套原则，按场景加权。

---

## 决策分类

> **原文**：
> ```
> ## Decision Classification
>
> Mechanical — one clearly right answer. Auto-decide silently.
> Taste — reasonable people could disagree. Auto-decide with recommendation, but surface
>   at the final gate. Three natural sources:
>   1. Close approaches — top two are both viable with different tradeoffs.
>   2. Borderline scope — in blast radius but 3-5 files, or ambiguous radius.
>   3. Codex disagreements — codex recommends differently and has a valid point.
>
> User Challenge — both models agree the user's stated direction should change.
> This is NEVER auto-decided.
> ```

**中文**：

```
决策类型
├── 机械决策（Mechanical）
│   ├── 答案明确，只有一个正确选择
│   ├── 静默自动决定，不记录为品味决策
│   └── 例：是否跑 Codex？→ 永远 yes
│
├── 品味决策（Taste）
│   ├── 合理的人可能有不同意见
│   ├── 自动决定（用 6 原则），但在最终门关呈现
│   └── 三种来源：
│       ├── 两个方案各有取舍（接近）
│       ├── 范围在爆炸半径边缘（3-5 个文件）
│       └── Codex 有不同意见且有道理
│
└── 用户挑战（User Challenge）
    ├── 两个模型都认为用户的方向需要改变
    ├── 永远不自动决定
    └── 在最终门关用更丰富的上下文呈现：
        ├── 用户说了什么（原始方向）
        ├── 两个模型推荐什么（变更）
        ├── 为什么（推理）
        ├── 我们可能缺失什么上下文（盲点承认）
        └── 如果我们错了，代价是什么
```

> **设计原理：用户挑战为什么永远不自动决定？**
> 当两个 AI 模型都同意"应该改变用户的方向"时，这是质量上不同于品味决策的情况。用户的原始方向是默认值——模型必须提出理由，而不是反过来。这保证了 `/autoplan` 永远不会悄悄地改变你想做什么，只会改变你怎么做。

---

## Phase 0：摄入 + 还原点

> **原文**：
> ```
> ## Phase 0: Intake + Restore Point
>
> Step 1: Capture restore point — Before doing anything, save the plan file's current
>   state to an external file. Write the plan file's full contents to the restore path
>   with a header including re-run instructions.
>
> Step 2: Read context — Read CLAUDE.md, TODOS.md, git log -30, git diff against the
>   base branch --stat. Detect UI scope (grep for view/rendering terms). Detect DX scope
>   (grep for developer-facing terms). Require 2+ matches.
>
> Step 3: Load skill files from disk — Read each file using the Read tool:
>   - ~/.claude/skills/gstack/plan-ceo-review/SKILL.md
>   - ~/.claude/skills/gstack/plan-design-review/SKILL.md (only if UI scope detected)
>   - ~/.claude/skills/gstack/plan-eng-review/SKILL.md
>   - ~/.claude/skills/gstack/plan-devex-review/SKILL.md (only if DX scope detected)
> ```

**中文**：

**Step 1（还原点）**：在做任何事之前，将方案文件的当前状态保存到外部文件，包含重新运行的说明。如果流水线中途失败，用户可以从这个还原点重启。

**Step 2（读取上下文）**：
- 读 CLAUDE.md、TODOS.md、最近 30 条 git log、diff 统计
- 探测 **UI 范围**：方案里有 `component`、`screen`、`button`、`modal` 等词（需要 2+ 匹配）→ 触发设计评审
- 探测 **DX 范围**：方案里有 `API`、`endpoint`、`CLI`、`SDK`、`SKILL.md` 等词 → 触发 DX 评审

**Step 3（加载技能文件）**：从磁盘实时读取每个评审技能的 SKILL.md。**注意跳过列表**：被 /autoplan 父级处理的章节（Preamble、遥测、Step 0 等）在子技能中跳过，避免重复执行。

> **设计原理：为什么设计评审和 DX 评审是条件性的？**
> 不是所有方案都有 UI，不是所有方案都面向开发者。条件触发避免了不必要的评审，同时保证当有 UI 或 DX 内容时不遗漏。还原点是"先存档再冒险"的工程习惯——出问题时不丢工作。

---

## Phase 1：CEO 评审（战略与范围）

> **原文**：
> ```
> ## Phase 1: CEO Review (Strategy & Scope)
>
> Follow plan-ceo-review/SKILL.md — all sections, full depth.
> Override: every AskUserQuestion → auto-decide using the 6 principles.
>
> Override rules:
> - Mode selection: SELECTIVE EXPANSION
> - Premises: GATE: Present premises to user for confirmation — this is the ONE
>   AskUserQuestion that is NOT auto-decided. Premises require human judgment.
> - Dual voices: always run BOTH Claude subagent AND Codex if available.
> ```

**中文**：

CEO 评审阶段的核心是挑战战略基础：这个方案解决的是正确的问题吗？有没有 10 倍影响力的重构？替代方案被充分探索了吗？

**关键覆盖规则**：

| 决策点 | 覆盖行为 |
|-------|---------|
| 模式选择 | 固定为 SELECTIVE EXPANSION（保持范围，精选扩展） |
| 前提假设 | **唯一不自动决定的 AskUserQuestion**——需要人来判断什么是正确的问题 |
| 替代方案 | 选最高完整性（P1），并列时选最简单（P5） |
| 范围扩展 | 爆炸半径内 + CC 努力 < 1 天 → 自动批准（P2） |
| Codex 分歧 | 策略分歧 → 品味决策；方向性分歧 → 用户挑战 |

**双声部（Dual Voices）**：Claude 子代理（前台，Agent 工具）+ Codex（Bash，read-only 沙箱）**顺序**运行，必须都完成才建立共识表：

```
CEO DUAL VOICES — CONSENSUS TABLE:
═══════════════════════════════════════════════════════════════
  Dimension                           Claude  Codex  Consensus
  ──────────────────────────────────── ─────── ─────── ─────────
  1. Premises valid?                   —       —      —
  2. Right problem to solve?           —       —      —
  3. Scope calibration correct?        —       —      —
  4. Alternatives sufficiently explored?—      —      —
  5. Competitive/market risks covered? —       —      —
  6. 6-month trajectory sound?         —       —      —
═══════════════════════════════════════════════════════════════
CONFIRMED = both agree. DISAGREE = models differ (→ taste decision).
```

> **设计原理：为什么前提假设不自动决定？**
> 前提假设回答的是"我们在解决正确的问题吗"——这是 CEO 评审中人的判断最不可替代的地方。AI 可以质疑前提，但不能代替人确认"是的，这就是我们要解决的问题"。

---

## Phase 2：设计评审（条件性）

> **原文**：
> ```
> ## Phase 2: Design Review (conditional — skip if no UI scope)
>
> Follow plan-design-review/SKILL.md — all 7 dimensions, full depth.
> Override rules:
> - Structural issues (missing states, broken hierarchy): auto-fix (P5)
> - Aesthetic/taste issues: mark TASTE DECISION
> - Design system alignment: auto-fix if DESIGN.md exists and fix is obvious
> ```

**中文**：设计评审只在 Phase 0 检测到 UI 范围时运行。覆盖规则区分了两类问题：

- **结构性问题**（缺少加载状态、错误状态、信息层级混乱）：自动修复（P5，显式优于聪明）
- **美学/品味问题**（颜色方案、布局偏好）：标记为品味决策，留给最终门关

设计评审同样运行双声部（Claude 设计子代理 + Codex 设计视角），但有一个关键区别：Claude 子代理保持完全独立（不知道 CEO 阶段的发现），而 Codex 提示中**包含** CEO 阶段的发现摘要——让 Codex 的评审更有上下文，同时保持 Claude 子代理的独立性。

---

## Phase 3：工程评审 + 双声部

> **原文**：
> ```
> ## Phase 3: Eng Review + Dual Voices
>
> Follow plan-eng-review/SKILL.md — all sections, full depth.
> Override rules:
> - Scope challenge: never reduce (P2)
> - Architecture choices: explicit over clever (P5)
>
> Required execution checklist (Eng):
> - Section 3 (Test Review) — NEVER SKIP OR COMPRESS.
>   This section requires reading actual code, not summarizing from memory.
>   Write the test plan artifact to disk.
> ```

**中文**：工程评审是流水线中最不可压缩的阶段。必须产出的内容：

| 产出物 | 位置 |
|-------|------|
| 架构 ASCII 依赖图 | 方案文件 |
| 测试图（代码路径 → 覆盖状态） | 方案文件 |
| 测试计划文件 | `~/.gstack/projects/$SLUG/` |
| 失败模式注册表 | 方案文件 |
| TODOS.md 更新 | 项目根目录 |

**工程共识表**：

```
ENG DUAL VOICES — CONSENSUS TABLE:
  Dimension                           Claude  Codex  Consensus
  1. Architecture sound?               —       —      —
  2. Test coverage sufficient?         —       —      —
  3. Performance risks addressed?      —       —      —
  4. Security threats covered?         —       —      —
  5. Error paths handled?              —       —      —
  6. Deployment risk manageable?       —       —      —
```

> **设计原理：为什么 Section 3（测试）永远不能压缩？**
> 测试评审是 Eng review 中最容易被 AI "假装完成"的部分——写一句"测试覆盖充分"比真正读代码、列出每个代码路径、确认对应测试存在要容易得多。这条规则强制要求：必须读实际代码，必须产出测试图文件，"no issues found"只有在展示了检查过什么之后才成立。

---

## Phase 3.5：DX 评审（条件性）

> **原文**：
> ```
> ## Phase 3.5: DX Review (conditional — skip if no developer-facing scope)
>
> Follow plan-devex-review/SKILL.md — all 8 DX dimensions, full depth.
> Override rules:
> - Mode selection: DX POLISH
> - Getting started friction: always optimize toward fewer steps (P5)
> - Error message quality: always require problem + cause + fix (P1, completeness)
> - API/CLI naming: consistency wins over cleverness (P5)
> ```

**中文**：DX 评审从开发者视角审查方案。关注 8 个维度：

1. 首次上手时间（TTHW — Time to Hello World）
2. API/CLI 命名一致性
3. 错误消息质量（问题 + 原因 + 修复方法）
4. 文档可找性与完整性
5. 升级路径安全性
6. 开发环境摩擦
7. 逃生舱口（能否覆盖所有默认值）
8. 竞争对手基准对比

**必须产出物**：开发者旅程地图（9 阶段表）、开发者同理叙事（第一人称视角）、DX 评分卡（所有 8 个维度打分）、TTHW 评估。

---

## 决策审计日志

> **原文**：
> ```
> ## Decision Audit Trail
>
> After each auto-decision, append a row to the plan file using Edit:
>
> | # | Phase | Decision | Classification | Principle | Rationale | Rejected |
> |---|-------|----------|-----------|-----------|----------|
>
> Write one row per decision incrementally (via Edit). This keeps the audit on disk,
> not accumulated in conversation context.
> ```

**中文**：每一个自动决定都写一行审计记录到方案文件。这不是可选的——"没有静默的自动决定"是 `/autoplan` 的核心承诺。用户事后可以查看每个决定是什么、依据哪条原则、拒绝了什么选项。

> **设计原理：为什么用 Edit 增量写而不是最后汇总？**
> 如果流水线中途失败（超时、崩溃），增量写入的审计记录依然存在于磁盘上。如果汇总到最后再写，中途失败就什么都没了。"写到磁盘"比"保留在对话上下文"更可靠——上下文会被压缩，磁盘不会。

---

## Phase 4：最终批准门关

> **原文**：
> ```
> ## Phase 4: Final Approval Gate
>
> STOP here and present the final state to the user.
>
> ### Decisions Made: [N] total ([M] auto-decided, [K] taste choices, [J] user challenges)
> ### User Challenges (both models disagree with your stated direction)
> ### Your Choices (taste decisions)
> ### Auto-Decided: [M] decisions [see Decision Audit Trail in plan file]
> ### Review Scores
> ### Cross-Phase Themes
>
> AskUserQuestion options:
> A) Approve as-is
> B) Approve with overrides
> B2) Approve with user challenge responses
> C) Interrogate
> D) Revise
> E) Reject
> ```

**中文**：这是整个流水线的最终汇报。格式设计体现了认知负荷管理：

| 情况 | 处理 |
|-----|------|
| 0 个用户挑战 | 跳过"用户挑战"章节 |
| 0 个品味决策 | 跳过"你的选择"章节 |
| 1-7 个品味决策 | 平铺列表 |
| 8+ 个品味决策 | 按阶段分组，并附警告："这个方案有异常高的歧义性" |

**跨阶段主题**（Cross-Phase Themes）是最有价值的信号——如果同一个问题在 CEO 评审和 Eng 评审中被独立标记，说明这不是个体 AI 的噪声，而是真实的风险。

---

## 完成：写入评审日志

> **原文**：
> ```
> ## Completion: Write Review Logs
>
> On approval, write 3 separate review log entries so /ship's dashboard recognizes them.
>
> gstack-review-log '{"skill":"plan-ceo-review","status":"STATUS","via":"autoplan",...}'
> gstack-review-log '{"skill":"plan-eng-review","status":"STATUS","via":"autoplan",...}'
> ```

**中文**：批准后，`/autoplan` 以 `/ship` 能识别的格式写入每个阶段的评审日志（`via: "autoplan"` 字段标注来源）。这样 `/ship` 的评审仪表板会知道"CEO、Eng（以及可能的 Design、DX）评审已完成"，可以放行发布。

---

## 重要规则

> **原文**：
> ```
> ## Important Rules
>
> - Never abort. The user chose /autoplan. Respect that choice.
> - Two gates. The non-auto-decided AskUserQuestions are: (1) premise confirmation
>   in Phase 1, and (2) User Challenges.
> - Log every decision. No silent auto-decisions.
> - Full depth means full depth. A one-sentence summary of a section is not "full
>   depth" — it is a skip. If you catch yourself writing fewer than 3 sentences for
>   any review section, you are likely compressing.
> - Artifacts are deliverables. They must exist on disk when the review completes.
> - Sequential order. CEO → Design → Eng → DX. Each phase builds on the last.
> ```

**中文**：

- **永远不中止**：用户选择了 `/autoplan`，就是选择了自动流水线。不要在中途重定向到交互式评审。
- **两个门控**：唯一不自动决定的是前提假设确认和用户挑战。其余全部自动。
- **记录每个决定**：没有静默的自动决定。
- **全深度的含义**：一行概括 = 跳过。写少于 3 句话的评审章节 = 在压缩。产出物必须存在于磁盘。
- **顺序不可违背**：CEO → Design → Eng → DX，每个阶段建立在上一个的基础上。

---

## 整体流程总结图

```
/autoplan 完整流程
═══════════════════════════════════════════════════════════════════

用户输入 /autoplan
        │
        ▼
[Phase 0: 摄入]
  保存还原点 → 读上下文 → 检测 UI/DX 范围 → 从磁盘加载技能文件
        │
        ▼
[Phase 1: CEO 评审]
  运行 plan-ceo-review 全部章节
  ┌──────────────────────────────────────────────────────┐
  │ 双声部：Claude 子代理（前台）→ Codex（Bash，只读）   │
  │ 生成 CEO 共识表（6 维度）                           │
  │ 自动决定：范围、替代方案、战略问题                  │
  │ ★ 唯一不自动决定：前提假设 → AskUserQuestion       │
  └──────────────────────────────────────────────────────┘
        │
        ▼（Phase 1 全部产出物写入方案文件后）
[Phase 2: 设计评审] ← 仅当 UI 范围检测到
  运行 plan-design-review 全 7 个维度
  结构性问题自动修复；美学问题 → 品味决策
        │
        ▼（Phase 2 完成后）
[Phase 3: 工程评审]
  运行 plan-eng-review 全部章节
  ┌──────────────────────────────────────────────────────┐
  │ 必须产出：架构 ASCII 图、测试图、测试计划文件       │
  │ Section 3（测试）永远不压缩                         │
  │ 双声部：Claude 子代理（独立）→ Codex（含前序上下文） │
  └──────────────────────────────────────────────────────┘
        │
        ▼（Phase 3 完成后）
[Phase 3.5: DX 评审] ← 仅当 DX 范围检测到
  运行 plan-devex-review 全 8 个维度
  TTHW 评估、DX 评分卡、开发者旅程地图
        │
        ▼
[Pre-Gate Verification]
  逐项检查所有必须产出物是否已写入
  缺失 → 补产（最多重试 2 次）
        │
        ▼
[Phase 4: 最终批准门关]
  ┌──────────────────────────────────────────────────────┐
  │ 呈现给用户：                                        │
  │   用户挑战（两个模型都认为应该改变你的方向）        │
  │   品味决策（供审阅或覆盖）                          │
  │   自动决定摘要（见审计日志）                        │
  │   各阶段评审分数 + 跨阶段主题                       │
  └──────────────────────────────────────────────────────┘
  用户选择：A批准 / B覆盖 / C追问 / D修改 / E拒绝
        │
        ▼（批准后）
[写入评审日志]
  gstack-review-log（CEO / Eng / Design / DX / 双声部）
  /ship 的仪表板将识别这些评审记录
        │
        ▼
建议下一步：/ship
```

---

## 设计核心思路汇总表

| 设计决策 | 具体机制 | 背后原因 |
|---------|---------|---------|
| 一条命令跑完全部 | 顺序加载并执行 4 个技能文件 | 消除 15-30 个中间问答的负担 |
| 6 条决策原则 | 替代用户回答中间 AskUserQuestion | 有原则的自动化，不是随机决定 |
| 品味决策延迟到最终门关 | 流程中标记，最后汇总呈现 | 减少打断，但保留人的最终审阅 |
| 前提假设永远不自动决定 | Phase 1 唯一的 AskUserQuestion | "解决正确的问题"是人的判断 |
| 用户挑战永远不自动决定 | 附带盲点承认和代价评估 | 方向性改变必须人决定，模型只提建议 |
| 双声部（Claude + Codex）顺序运行 | 前台阻塞，不并行 | 并行会混淆上下文；顺序保证独立性 |
| 每个决定写审计日志 | 增量 Edit 到方案文件 | 无静默决定；流水线失败不丢记录 |
| 设计/DX 评审条件触发 | Phase 0 检测关键词（2+ 匹配） | 不做不需要的评审，但有就不漏 |
| 全深度执行（不压缩） | 3 句话以下视为压缩 | 真正的评审需要真正的分析 |
| 产出物必须存在于磁盘 | Phase 4 前逐项 pre-gate 验证 | "评审完成"的证据，而非声称 |
