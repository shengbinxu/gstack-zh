# `/ship` 技能逐段中英对照注解

> 对应源文件：`ship/SKILL.md`（2500+ 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: ship
preamble-tier: 4
version: 1.0.0
description: |
  Ship workflow: detect + merge base branch, run tests, review diff, bump VERSION,
  update CHANGELOG, commit, push, create PR. Use when asked to "ship", "deploy",
  "push to main", "create a PR", "merge and push", or "get it deployed".
  Proactively invoke this skill (do NOT push/PR directly) when the user says code
  is ready, asks about deploying, wants to push code up, or asks to create a PR.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - WebSearch
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/ship` 触发。
- **preamble-tier: 4**：最高级别的 Preamble（共 4 级）。包含完整的环境初始化、升级检查、遥测、路由注入等全套上下文。`/ship` 是最核心的技能，也是最复杂的，因此需要最完整的前置上下文。
- **description**: 完整的发布工作流。检测并合并基础分支、运行测试、评审差异、bump 版本号、更新 CHANGELOG、提交、推送、创建 PR。
- **allowed-tools**: 注意包含了 **Edit**（修改文件）、**Agent**（并行子任务）、**AskUserQuestion**（与用户交互）——这是一个完整的写操作技能，不只是读取和分析。

> **设计原理：为什么 allowed-tools 这么全？**
> `/ship` 需要做一切：修复代码问题（Edit）、并行运行评审专家（Agent）、向用户确认 MINOR/MAJOR 版本升级（AskUserQuestion）、查找最佳实践（WebSearch）。它是整个 gstack 工作流的终点，也是工作量最大的技能。

---

## {{PREAMBLE}} 展开区

Tier 4 的 Preamble 在编译时展开，包含约 500 行前置上下文，其作用如下：

1. **gstack 升级检查**：启动时自动检测是否有新版本可用
2. **Session 追踪**：创建 `~/.gstack/sessions/$PPID` 标记文件，追踪当前会话
3. **遥测初始化**：记录 `skill:"ship"` 使用事件到本地 JSONL 文件（用户可选退出）
4. **分支检测**：`_BRANCH=$(git branch --show-current)` — 确保后续命令使用正确的分支名
5. **Boil the Lake 原则**：首次运行时介绍"完整性近乎免费"的核心理念
6. **路由规则注入**：检测 CLAUDE.md 是否有 Skill routing，没有则提示添加
7. **Vendoring 检测**：检测项目是否内嵌了过时的 gstack 副本，提示迁移到 team mode
8. **Spawned Session 支持**：如果在 OpenClaw 等编排器中运行，自动禁用交互式提示
9. **Context Recovery（上下文恢复）**：读取最近的 checkpoints 和 timeline，输出欢迎简报

> **设计原理：为什么 /ship 需要 tier 4？**
> `/ship` 在整个开发周期的末端运行，此时上下文最复杂——你需要知道之前是否已经 bump 过 VERSION、之前的 review 是否还有效、测试是否已经通过。Tier 4 的 Context Recovery 机制让 AI 在会话中途能重建这些状态。

---

## Step 0：平台检测与基础分支确定

> **原文**：
> ```
> First, detect the git hosting platform from the remote URL:
> git remote get-url origin
> - If URL contains "github.com" → platform is GitHub
> - If URL contains "gitlab" → platform is GitLab
> - Otherwise, check CLI availability
> ```

**中文**：首先检测 git 托管平台。通过 `git remote get-url origin` 获取远端 URL，根据 URL 判断是 GitHub 还是 GitLab。如果无法从 URL 判断，则分别尝试 `gh auth status` 和 `glab auth status`。

然后确定基础分支（base branch）：
- GitHub：`gh pr view --json baseRefName` → `gh repo view --json defaultBranchRef`
- GitLab：`glab mr view -F json` 提取 `target_branch`
- 兜底：`git symbolic-ref refs/remotes/origin/HEAD` → `main` → `master`

> **设计原理**：后续所有 `git diff`、`git merge`、PR 创建命令都需要正确的基础分支名。如果用了错的分支名，整个工作流会失败。这是必须首先完成的元信息收集。

---

## 核心设计：完全自动化

> **原文**：
> ```
> You are running the /ship workflow. This is a non-interactive, fully automated
> workflow. Do NOT ask for confirmation at any step. The user said /ship which
> means DO IT. Run straight through and output the PR URL at the end.
> ```

**中文**：你在运行 `/ship` 工作流。这是一个**非交互式、全自动**工作流。不要在任何步骤询问确认。用户说了 `/ship` 就意味着"去做"。径直跑完所有步骤，最后输出 PR URL。

**只在以下情况停下来**：

| 停止条件 | 原因 |
|---------|------|
| 当前在基础分支上 | 不能从 main 分支 ship |
| 无法自动解决的合并冲突 | 需要人工干预 |
| 分支内的测试失败 | 你自己的代码坏了 |
| 评审发现需要判断的问题（ASK 类） | 需要用户决策 |
| MINOR 或 MAJOR 版本需要升级 | 重大变更需要确认 |
| 覆盖率低于最低阈值 | 质量门禁 |
| Plan 中有 NOT DONE 项目 | 计划未完成 |

**永远不要停下来**（自动处理）：

| 自动处理项 | 处理方式 |
|-----------|---------|
| 未提交的更改 | 直接包含进去 |
| VERSION 选择 | 自动选 MICRO 或 PATCH |
| CHANGELOG 内容 | 从 diff 自动生成 |
| 提交信息 | 自动拟定 |
| 可自动修复的评审问题 | 直接修复后继续 |

> **设计原理：为什么强调"不要停下来"？**
> 这是对抗 AI 过度谨慎行为的刻意设计。如果 AI 在每个小决定上都询问用户，`/ship` 就变成了一个交互式向导，失去了自动化的价值。用户输入 `/ship` 的意图就是"帮我做完"。

---

## Step 1：起飞检查（Pre-flight）

> **原文**：
> ```
> 1. Check the current branch. If on the base branch or the repo's default branch,
>    abort: "You're on the base branch. Ship from a feature branch."
> 2. Run git status (never use -uall). Uncommitted changes are always included.
> 3. Run git diff <base>...HEAD --stat and git log <base>..HEAD --oneline
> 4. Check review readiness — display the Review Readiness Dashboard
> ```

**中文**：
1. 检查当前分支——如果在基础分支上则中止
2. 运行 `git status`（不要用 `-uall`）——未提交的更改直接包含
3. 查看 diff 统计和提交日志，了解要发布什么
4. 检查评审准备状态——显示评审看板

---

## Step 1：Review Readiness Dashboard（评审准备看板）

这是 `/ship` 最重要的显示界面之一。

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
> ```

**各字段含义**：

| 字段 | 含义 |
|-----|------|
| Review | 评审类型名称 |
| Runs | 在当前分支上运行过的次数 |
| Last Run | 最近一次运行的时间戳 |
| Status | CLEAR（通过）、— （未运行）、issues_found（有问题） |
| Required | YES = 必须通过才能 ship；no = 仅供参考 |

**VERDICT（最终裁决）逻辑**：

```
如果 Eng Review 有 >= 1 次记录 AND 在 7 天内 AND status="clean"
→ VERDICT: CLEARED

否则
→ VERDICT: NOT CLEARED（但 /ship 会在 Step 3.5 自己运行评审）
```

**评审类型说明**：

| 评审 | 必须 | 触发时机 |
|-----|------|---------|
| Eng Review | YES | 代码质量、架构、测试 |
| CEO Review | no | 产品/业务变更时推荐 |
| Design Review | no | 前端变更时推荐 |
| Adversarial | 自动 | 每次 /review 都内置 |
| Outside Voice | no | Codex 或 Claude 的第二意见 |

**staleness（过期检测）**：每个评审条目与当前 HEAD commit 比较。如果评审后有新提交，显示 "N commits since review" 警告。

> **设计原理：为什么只有 Eng Review 是必须的？**
> CEO Review 关注业务价值判断，设计评审关注视觉效果，这些都是可选的高质量保障。但工程评审（代码安全、测试覆盖、架构合理性）是发布任何代码的基本门槛，不可跳过。Adversarial Review 虽然重要但已经内置在 `/review` 里，不需要单独检查。

---

## Step 1.5：Distribution Pipeline 检查

> **原文**：
> ```
> If the diff introduces a new standalone artifact (CLI binary, library package, tool)
> — not a web service with existing deployment — verify that a distribution pipeline exists.
> ```

**中文**：如果 diff 引入了新的独立产出物（CLI 二进制、库包、工具），但没有已有的部署管道，则检查是否有 release workflow。如果没有，询问用户是否要添加 CI/CD 发布管道。

> **设计原理**：代码 merge 了但用户下不到产物，这是一个常见的发布盲区。新 CLI 工具必须有构建和发布流水线，否则 merge 只是代码入库，用户拿不到可执行文件。

---

## Step 2：合并基础分支（先于测试）

> **原文**：
> ```
> Fetch and merge the base branch into the feature branch so tests run
> against the merged state:
> git fetch origin <base> && git merge origin/<base> --no-edit
> ```

**中文**：在运行测试之前先合并基础分支，确保测试在合并后的状态上运行。

**冲突处理策略**：
- 简单冲突（VERSION 文件、schema.rb 排序、CHANGELOG 顺序）：自动解决
- 复杂或有歧义的冲突：STOP，展示冲突内容

> **设计原理：为什么先 merge 再测试？**
> 这是对抗"测试通过但 merge 后失败"问题的核心设计。如果先测试再合并，可能在合并时引入新的冲突和破坏。先合并到最新基础分支，再测试，才是真正意义上的"这个 PR merge 后不会坏"。

---

## Step 2.5：测试框架自举（Test Framework Bootstrap）

如果项目没有测试框架，`/ship` 会先帮你建一个。

```
无测试框架检测到
     ↓
询问用户选择框架（vitest/rspec/pytest/go-test...）
     ↓
安装依赖、创建配置
     ↓
生成 3-5 个真实测试（针对最近修改的高风险代码）
     ↓
运行验证
     ↓
创建 .github/workflows/test.yml（GitHub Actions）
     ↓
写 TESTING.md + 更新 CLAUDE.md
     ↓
提交（chore: bootstrap test framework）
```

> **设计原理：为什么 /ship 要帮你建测试框架？**
> "100% 测试覆盖是 vibe coding 安全的关键。没有测试的 vibe coding 只是 yolo coding。"这是 gstack 的核心信念。如果你连测试框架都没有就 ship，那你不知道自己 ship 了什么。

---

## Step 3：运行测试

> **原文**：
> ```
> Run both test suites in parallel:
> bin/test-lane 2>&1 | tee /tmp/ship_tests.txt &
> npm run test 2>&1 | tee /tmp/ship_vitest.txt &
> wait
> ```

**中文**：并行运行两个测试套件。

### Test Failure Ownership Triage（测试失败归责分类）

当测试失败时，不是立刻停止，而是先判断**这个失败是谁引起的**：

```
测试失败
    ↓
    ├── 分支内失败（你改的代码导致的）
    │       → 必须修复，STOP
    │
    └── 预存在失败（与本分支无关的历史问题）
            │
            ├── solo 仓库
            │     → AskUserQuestion: A)现在修复 B)加 P0 TODO C)跳过
            │
            └── 协作仓库
                  → AskUserQuestion: A)自己修 B)blame+创建 GitHub issue C)加 TODO D)跳过
```

> **设计原理**：把"我的测试失败"和"已经存在的失败"混在一起处理是错误的。本分支无关的历史失败，在协作仓库中可能是别人的责任。gstack 的做法是先分清归属，再决定行动。

---

## Step 3.25：Eval Suites（LLM 评估套件，条件触发）

当 diff 包含 prompt 相关文件时强制运行。

> **原文**：
> ```
> Evals are mandatory when prompt-related files change.
> /ship is a pre-merge gate, so always use full tier
> (Sonnet structural + Opus persona judges).
> ```

**评估层级对比**：

| 层级 | 适用场景 | 速度（缓存后） | 成本 |
|-----|---------|-------------|------|
| fast（Haiku） | 开发迭代、冒烟测试 | ~5s | ~$0.07/次 |
| standard（Sonnet） | 日常开发 | ~17s | ~$0.37/次 |
| **full（Opus persona）** | **`/ship` 和 pre-merge** | ~72s | ~$1.27/次 |

> **设计原理**：prompt 变更影响 LLM 的输出质量，这是传统单元测试无法覆盖的维度。必须用评估套件验证 LLM 输出仍然符合质量标准。

---

## Step 3.4：测试覆盖率审计（Test Coverage Audit）

这是 `/ship` 中最复杂的步骤之一——不是简单地运行 `coverage` 命令，而是 AI 主动分析代码路径。

**执行流程**：

```
1. 追踪每个被修改的代码路径（不只是函数，是整个执行链）
2. 画出 ASCII 代码路径图（含所有条件分支、错误路径）
3. 同时画出用户流程图（用户操作序列、边界情况）
4. 对照现有测试，标注每个路径是否有测试
5. 计算 AI 评估的覆盖率百分比
6. 根据目标阈值决定是否继续
```

**ASCII 覆盖率图示例**：

```
CODE PATH COVERAGE
===========================
[+] src/services/billing.ts
    │
    ├── processPayment()
    │   ├── [★★★ TESTED] Happy path + card declined — billing.test.ts:42
    │   ├── [GAP]         Network timeout — NO TEST
    │   └── [GAP]         Invalid currency — NO TEST
    │
    └── refundPayment()
        ├── [★★  TESTED] Full refund — billing.test.ts:89
        └── [★   TESTED] Partial refund (存在性检查) — billing.test.ts:101
```

**覆盖率门禁逻辑**：

| 覆盖率范围 | 处理方式 |
|-----------|---------|
| >= target（目标阈值） | 通过，继续 |
| >= minimum，< target | AskUserQuestion：A)生成更多测试 B)接受风险继续 C)标记为不需要测试 |
| < minimum（最低阈值） | AskUserQuestion，强烈建议生成测试 |

**REGRESSION RULE（回归测试铁律）**：

> 当覆盖率审计发现**回归**（diff 破坏了之前工作的代码），立刻写回归测试。不询问用户，不跳过。回归是最高优先级的测试，因为它证明了东西坏了。

---

## Step 3.45：Plan 完成度审计

如果有计划文件（plan file），检查 diff 是否完成了所有计划项目。

**四种分类状态**：

| 状态 | 含义 |
|-----|------|
| DONE | diff 中有明确证据表明该项已实现 |
| PARTIAL | 有部分实现但不完整 |
| NOT DONE | diff 中没有该项的任何痕迹 |
| CHANGED | 用不同方式实现了相同目标 |

**门禁逻辑**：如果有 NOT DONE 项目，询问用户：A)停下来先实现 B)继续（创建 P1 TODO）C)有意删除了这个范围。

---

## Step 3.48：Scope Drift 检测

> **原文**：
> ```
> Before reviewing code quality, check: did they build what was requested
> — nothing more, nothing less?
> ```

**中文**：在评审代码质量之前，检查：**他们是否只构建了被要求的内容——不多也不少？**

输出格式：
```
Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
Intent: <1行总结被要求做什么>
Delivered: <1行总结 diff 实际做了什么>
```

这是**仅供参考**的——不阻塞发布，但让你了解是否有范围蔓延或遗漏需求。

---

## Step 3.5：Pre-Landing Review（落地前评审）

`/ship` 内置了完整的代码评审，不需要单独运行 `/review`。

**两个评审阶段**：

1. **Pass 1（关键）**：SQL & 数据安全、LLM 输出信任边界
2. **Pass 2（信息性）**：所有其他类别

**每个发现必须包含置信度分数（1-10）**：

| 分数 | 含义 | 展示规则 |
|-----|------|---------|
| 9-10 | 通过读特定代码验证，有具体 bug 或漏洞 | 正常展示 |
| 7-8 | 高置信度模式匹配，极可能正确 | 正常展示 |
| 5-6 | 中等，可能是误报 | 加注 "Medium confidence，请核实" |
| 3-4 | 低置信度 | 移到附录，不在主报告中 |
| 1-2 | 推测 | 只有 P0 级别才报告 |

### Step 3.55：Review Army — 专家并行派遣

根据 diff 内容自动选择并行运行的专家：

```
检测 diff 范围（SCOPE_AUTH、SCOPE_BACKEND、SCOPE_FRONTEND...）
          ↓
          ├── 50+ 行变更 → 总是派遣 Testing + Maintainability 专家
          │
          ├── SCOPE_AUTH=true 或 SCOPE_BACKEND=true AND 100+ 行 → 派遣 Security
          ├── SCOPE_BACKEND 或 SCOPE_FRONTEND → 派遣 Performance
          ├── SCOPE_MIGRATIONS=true → 派遣 Data Migration
          ├── SCOPE_API=true → 派遣 API Contract
          └── SCOPE_FRONTEND=true → 派遣 Design
```

所有选中的专家以并行 Agent 子任务运行，每个专家输出 JSON 格式的发现，最后合并和去重。

**PR 质量分公式**：
```
quality_score = max(0, 10 - (critical_count * 2 + informational_count * 0.5))
```

### Step 3.8：对抗性评审（Adversarial Review，永远开启）

两层对抗：

1. **Claude 对抗子 Agent**（始终运行）：独立上下文，像攻击者和混沌工程师一样思考
2. **Codex 对抗挑战**（有 Codex 时运行）：跨模型覆盖
3. **Codex 结构化评审**（仅 200+ 行 diff）：大型变更的额外把关

**跨模型综合**：
```
ADVERSARIAL REVIEW SYNTHESIS:
  High confidence (多个来源都发现): [交叉确认的发现]
  Unique to Claude structured review
  Unique to Claude adversarial
  Unique to Codex
  Models used: Claude structured ✓  Claude adversarial ✓/✗  Codex ✓/✗
```

> **设计原理**：单一审查视角有盲区。专家系统（Specialist Army）从领域角度找问题，对抗子 Agent 从攻击者角度找问题，Codex 从不同模型角度找问题。三层覆盖，减少漏网之鱼。

---

## Step 4：VERSION Bump（自动决策）

这是 `/ship` 中最有特色的设计之一。

> **原文**：
> ```
> Auto-decide the bump level based on the diff:
> - MICRO (4th digit): < 50 lines changed, trivial tweaks, typos, config
> - PATCH (3rd digit): 50+ lines changed, no feature signals detected
> - MINOR (2nd digit): ASK if ANY feature signal detected, OR 500+ lines, OR new modules
> - MAJOR (1st digit): ASK — only for milestones or breaking changes
> ```

**版本号格式**：`MAJOR.MINOR.PATCH.MICRO`（4 位）

**自动判断逻辑**：

```
查看 diff 行数
    ↓
    ├── < 50 行，无新功能信号 → MICRO（第4位）自动 bump
    │
    ├── 50+ 行，无功能信号 → PATCH（第3位）自动 bump
    │
    ├── 有功能信号（新路由/页面、新迁移、branch 以 feat/ 开头）
    │   OR 500+ 行
    │   OR 新增模块/包
    │   → MINOR（第2位）询问用户
    │
    └── 里程碑或破坏性变更 → MAJOR（第1位）询问用户
```

**示例**：`0.19.1.0` + PATCH → `0.19.2.0`（右侧数字重置为0）

**幂等性保护**：如果 VERSION 文件在基础分支和当前 HEAD 之间已经不同，说明本分支已经 bump 过，跳过 bump 动作但继续读取版本号。

> **设计原理：为什么是 4 位版本号？**
> 4 位版本号让细粒度控制成为可能。MICRO 用于每天多次的小修小补，不惊动用户；PATCH 用于通常的修复和重构；MINOR 才是真正的新功能。这样每次提交都有对应的版本含义，PR 历史和 CHANGELOG 更有价值。

---

## CHANGELOG（自动生成）

> **原文**：
> ```
> Do NOT ask the user to describe changes. Infer from the diff and commit history.
> Every commit must map to at least one bullet point.
> Voice: Lead with what the user can now DO that they couldn't before.
> ```

**生成步骤**：

1. 读取所有本分支提交（用作核查清单）
2. 读取完整 diff，理解每个提交实际改了什么
3. 按主题分组：新功能 / 性能 / Bug 修复 / 清理 / 基础设施
4. 写 CHANGELOG 条目，覆盖所有组
5. 对照提交列表核查：每个提交必须对应至少一个 bullet point

**写作原则**：以用户现在能**做**什么开头，不是用了什么技术。

```markdown
## [0.19.2.0] - 2026-04-07

### Added
- 用户现在可以直接在列表页批量导出（不再需要逐个打开）

### Fixed
- 修复了在 Safari 下付款表单无法提交的问题
```

---

## Step 5.5：TODOS.md 自动更新

> **原文**：
> ```
> Cross-reference the project's TODOS.md against the changes being shipped.
> Mark completed items automatically; prompt only if the file is missing or disorganized.
> ```

**三个场景**：

| 场景 | 处理方式 |
|-----|---------|
| TODOS.md 不存在 | AskUserQuestion：是否创建？ |
| 存在但格式混乱 | AskUserQuestion：是否整理？ |
| 存在且格式正确 | 自动检测已完成项并移动到 Completed 区 |

**自动检测逻辑**：通过 diff 和提交历史，保守地判断哪些 TODO 项被本次 PR 完成了。

---

## Step 6：提交（Bisectable Chunks）

> **原文**：
> ```
> Goal: Create small, logical commits that work well with git bisect and help
> LLMs understand what changed.
> ```

**提交顺序**（先提交依赖，后提交依赖方）：

1. **基础设施**：数据库迁移、配置变更、路由添加
2. **模型与服务**：新模型、服务、concerns（含测试）
3. **控制器与视图**：控制器、视图、React 组件（含测试）
4. **版本文件**：VERSION + CHANGELOG + TODOS.md（最后一个提交）

**最后一个提交的特殊格式**：

```bash
git commit -m "chore: bump version and changelog (vX.Y.Z.W)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

> **设计原理：为什么要 bisectable commits？**
> `git bisect` 依赖每个提交都是独立有效的。如果把所有变更压成一个大 commit，bisect 就失效了。小而逻辑清晰的提交，让 LLM 和人类都更容易理解"这个 PR 到底改了什么"。

---

## Step 6.5：验证门禁（IRON LAW）

> **原文**：
> ```
> IRON LAW: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.
> "Should work now" → RUN IT.
> "I'm confident" → Confidence is not evidence.
> "I already tested earlier" → Code changed since then. Test again.
> ```

**中文**：铁律：没有新的验证证据，不能声称工作完成。

如果在 Step 4-6 中有任何代码变更（评审修复等），必须重新运行测试。之前测试的结果已经过时。

---

## Step 7：推送

幂等性检查：对比 LOCAL 和 REMOTE HEAD，如果已经推送则跳过推送命令但继续到 Step 8。

```bash
git push -u origin <branch-name>
```

---

## Step 8：创建 PR/MR

**幂等性处理**：如果 PR 已存在，更新 PR body（用本次运行的新鲜结果）；如果不存在，创建新 PR。

**PR body 包含**：

- 修改摘要
- 测试覆盖率审计结果
- 计划完成度（如果有 plan file）
- 验证结果（如果有 dev server）
- 评审发现汇总
- TODOS.md 更新摘要

---

## 完整流程总结图（ASCII）

```
用户: /ship
    │
    ├── [Step 0] 检测平台（GitHub/GitLab）+ 基础分支
    │
    ├── [Step 1] 起飞检查
    │   └── 显示 Review Readiness Dashboard
    │       └── 如未通过 Eng Review → 提示（不阻塞）
    │
    ├── [Step 1.5] Distribution Pipeline 检查
    │
    ├── [Step 2] git fetch + git merge origin/<base>
    │   └── 处理合并冲突（简单的自动解决）
    │
    ├── [Step 2.5] 测试框架自举（如果没有测试框架）
    │
    ├── [Step 3] 并行运行测试
    │   └── 失败 → 归责分类 → 分支内失败 STOP / 预存在失败 问用户
    │
    ├── [Step 3.25] Eval Suites（prompt 文件变更时触发）
    │
    ├── [Step 3.4] AI 测试覆盖率审计
    │   └── 低于阈值 → 生成测试 / 接受风险
    │
    ├── [Step 3.45] Plan 完成度审计（如果有 plan file）
    │   └── NOT DONE 项 → 询问用户
    │
    ├── [Step 3.47] 自动 QA 验证（如果有 dev server）
    │
    ├── [Step 3.48] Scope Drift 检测（仅报告）
    │
    ├── [Step 3.5] Pre-Landing Review
    │   ├── 读 checklist.md
    │   ├── 两阶段扫描（CRITICAL + INFORMATIONAL）
    │   ├── [Step 3.55] 专家并行评审（Testing/Security/Performance...）
    │   ├── [Step 3.8] 对抗性评审（Claude + Codex）
    │   └── Fix-First：自动修复 AUTO-FIX，询问 ASK
    │       └── 有修复 → 提交 → STOP（让用户重新运行 /ship）
    │
    ├── [Step 3.75] Greptile 评审评论处理（如果有 PR）
    │
    ├── [Step 4] VERSION Bump
    │   ├── MICRO/PATCH → 自动
    │   └── MINOR/MAJOR → 询问用户
    │
    ├── [CHANGELOG] 从 diff 自动生成
    │
    ├── [Step 5.5] TODOS.md 自动更新
    │
    ├── [Step 6] 创建 bisectable commits
    │   └── 最后 commit 含 VERSION + CHANGELOG + Co-author
    │
    ├── [Step 6.5] 验证门禁（如有代码变更则重新测试）
    │
    ├── [Step 7] git push -u origin <branch>
    │
    └── [Step 8] 创建/更新 PR
        └── 输出 PR URL
```

---

## 设计核心思路汇总表

| 设计决策 | 原则 | 说明 |
|---------|------|------|
| 完全自动化为默认 | 减少摩擦 | 用户说 `/ship` 就意味着"做完它"，不要来回确认 |
| 合并基础分支先于测试 | 真实环境测试 | 测试必须在合并态上运行，否则通过了也可能 merge 后失败 |
| 4 位版本号自动选择 | 语义版本 | diff 大小和功能信号决定版本级别，MINOR/MAJOR 才需要人工判断 |
| AI 覆盖率审计 | 代码路径 | 不依赖 coverage 工具，手动追踪每个分支路径 |
| IRON LAW 验证门禁 | 诚实性 | 有代码变更就必须重新测试，"我有信心"不是证据 |
| Bisectable commits | 可维护性 | 每个 commit 独立有效，支持 git bisect |
| 专家并行评审 | 覆盖率 | 不同领域专家并行，减少单点盲区 |
| Review Readiness Dashboard | 可视化 | 一眼看出 PR 的评审状态，哪些通过了哪些没有 |
| CHANGELOG 自动生成 | 效率 | 从 diff 和提交历史推断，不打扰用户描述变更 |
| Scope Drift 检测 | 质量意识 | 提醒开发者：你构建的是否是被要求的，不多不少 |
