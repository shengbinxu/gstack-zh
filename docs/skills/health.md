# `/health` 技能逐段中英对照注解

> 对应源文件：[`health/SKILL.md`](https://github.com/garrytan/gstack/blob/main/health/SKILL.md)（801 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: health
preamble-tier: 2
version: 1.0.0
description: |
  Code quality dashboard. Wraps existing project tools (type checker, linter,
  test runner, dead code detector, shell linter), computes a weighted composite
  0-10 score, and tracks trends over time. Use when: "health check",
  "code quality", "how healthy is the codebase", "run all checks",
  "quality score". (gstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/health` 触发。
- **preamble-tier: 2**: Preamble 详细度级别 2。包含基础的 repo 检测和会话管理，但比 tier 3/4 轻量。Health 不需要 "Search Before Building" 层——它的工作是运行工具，不是生成代码。
- **description**: 代码质量仪表盘。包装项目已有工具（类型检查器、lint、测试运行器、死代码检测器、shell linter），计算加权复合 0-10 分，追踪随时间变化的趋势。
- **allowed-tools**: 注意包含了 `Edit` 和 `Write`——health 需要把配置写入 `CLAUDE.md`，把历史记录写入 `~/.gstack/`。这与 `/plan-eng-review` 形成对比（review 只读不写）。

> **设计原理：为什么包含 Edit/Write？**
> Health 有两类写操作：
> 1. 把检测到的 Health Stack 持久化到 `CLAUDE.md`（一次性配置）
> 2. 把每次运行结果追加到 `~/.gstack/projects/$SLUG/health-history.jsonl`（趋势追踪）
> 如果没有 Write，趋势功能就不存在了。

---

## 角色设定：Staff 工程师 + CI 仪表盘

> **原文（第 537-544 行）**：
> ```
> # /health -- Code Quality Dashboard
>
> You are a **Staff Engineer who owns the CI dashboard**. You know that code quality
> isn't one metric -- it's a composite of type safety, lint cleanliness, test coverage,
> dead code, and script hygiene. Your job is to run every available tool, score the
> results, present a clear dashboard, and track trends so the team knows if quality
> is improving or slipping.
>
> **HARD GATE:** Do NOT fix any issues. Produce the dashboard and recommendations only.
> The user decides what to act on.
> ```

**中文**：你是**负责 CI 仪表盘的 Staff 工程师**。你知道代码质量不是单一指标——它是类型安全、lint 整洁度、测试覆盖、死代码、脚本规范的复合体。你的工作是运行所有可用工具、给结果打分、呈现清晰的仪表盘，追踪趋势让团队知道质量是在改善还是在下滑。

**HARD GATE（硬性约束）：不修复任何问题。只生成仪表盘和建议。由用户决定采取行动。**

### HARD GATE 的设计原理

这是 `/health` 最重要的设计决策。为什么不让 AI 直接修复？

```
诊断 vs 治疗 的职责分离

/health                          /qa (或手动修复)
  |                                    |
  |-- 运行工具                          |-- 修复问题
  |-- 呈现仪表盘                        |-- 验证修复
  |-- 追踪趋势                          |-- 提交代码
  |-- 生成建议
  |
  [STOP: 不动代码]
```

**原因 1：可重现性**。诊断阶段的结果应该是稳定的——你需要"真实基线"，不是被 AI 修改过的状态。

**原因 2：所有权**。团队需要理解并拥有这些修复，而不是让 AI 神秘地改掉若干文件。

**原因 3：优先级**。12 个 lint 警告、2 个测试失败、4 个死代码——哪个先修？这是业务决策，不是技术决策。

**原因 4：与 /qa 的分工**：
- `/health` = 全局代码质量审计（静态分析 + 测试）
- `/qa` = 功能测试（实际运行 app，测试用户流程）

---

## Preamble 区（第 23-260 行）

Preamble 是所有 gstack 技能共享的前置初始化代码，在技能核心逻辑运行之前执行。详细说明见 `/plan-eng-review` 注解。这里只记录 health 特有的点：

**Telemetry 记录**（第 53 行）：
```bash
echo '{"skill":"health","ts":"...","repo":"..."}'  >> ~/.gstack/analytics/skill-usage.jsonl
```

每次运行都会记录技能名、时间戳、repo 名。这是 gstack 的使用统计基础——帮助团队了解哪些技能最常用。

**CLAUDE.md 路由注入**（第 211 行）：
```
- Code quality, health check → invoke health
```

当用户第一次运行任何 gstack 技能时，系统会尝试把路由规则注入到 CLAUDE.md。这条规则告诉 Claude：当用户说"代码质量"或"健康检查"时，自动触发 `/health`。

---

## Step 1：检测 Health Stack（第 553-613 行）

### 优先读取配置

> **原文**：
> ```
> Read CLAUDE.md and look for a `## Health Stack` section. If found, parse the tools
> listed there and skip auto-detection.
> ```

**中文**：读取 CLAUDE.md 并查找 `## Health Stack` 部分。如果找到，解析其中列出的工具并跳过自动检测。

**设计原理**：配置优先于检测。如果用户已经定义了工具链，就尊重它，不要重新猜测。这避免了在同一项目上每次运行都重复"你用什么测试框架？"的交互。

### 自动检测逻辑

如果没有配置，运行自动检测：

```bash
# 类型检查器检测
[ -f tsconfig.json ] && echo "TYPECHECK: tsc --noEmit"

# Linter 检测（多种工具，按优先级）
[ -f biome.json ] || [ -f biome.jsonc ] && echo "LINT: biome check ."
ls eslint.config.* .eslintrc.* .eslintrc 2>/dev/null | head -1 | xargs -I{} echo "LINT: eslint ."
[ -f .pylintrc ] || [ -f pyproject.toml ] && grep -q "pylint\|ruff" pyproject.toml 2>/dev/null && echo "LINT: ruff check ."

# 测试运行器检测
[ -f package.json ] && grep -q '"test"' package.json 2>/dev/null && echo "TEST: ..."
[ -f pyproject.toml ] && grep -q "pytest" pyproject.toml 2>/dev/null && echo "TEST: pytest"
[ -f Cargo.toml ] && echo "TEST: cargo test"
[ -f go.mod ] && echo "TEST: go test ./..."

# 死代码检测器
command -v knip >/dev/null 2>&1 && echo "DEADCODE: knip"

# Shell linter
command -v shellcheck >/dev/null 2>&1 && ls *.sh scripts/*.sh bin/*.sh 2>/dev/null | ...
```

### 检测覆盖的语言栈

| 检测文件 | 推断工具 | 适用语言 |
|----------|----------|----------|
| `tsconfig.json` | `tsc --noEmit` | TypeScript |
| `biome.json/jsonc` | `biome check .` | JS/TS |
| `eslint.config.*` / `.eslintrc*` | `eslint .` | JS/TS |
| `pyproject.toml` + ruff/pylint | `ruff check .` | Python |
| `package.json` scripts.test | 读取 scripts.test 值 | JS/TS/Node |
| `pyproject.toml` + pytest | `pytest` | Python |
| `Cargo.toml` | `cargo test` | Rust |
| `go.mod` | `go test ./...` | Go |
| `knip` 命令存在 | `knip` | JS/TS（死代码）|
| `shellcheck` 命令存在 | `shellcheck` | Shell 脚本 |

### 流程图：检测 → 确认 → 持久化

```
CLAUDE.md 存在 Health Stack?
        |
       YES ──────────────────────────────────────────→ 使用配置的工具
        |
       NO
        |
        ↓
   运行自动检测脚本
        |
        ↓
   AskUserQuestion: 检测到以下工具，是否正确？
        |
       ┌─────────────────┬──────────────────┬──────────────────┐
       A)                B)                  C)
  写入CLAUDE.md      先调整工具           直接运行
  然后运行           再写入CLAUDE.md      不持久化
```

### Health Stack 持久化格式

```markdown
## Health Stack

- typecheck: tsc --noEmit
- lint: biome check .
- test: bun test
- deadcode: knip
- shell: shellcheck *.sh scripts/*.sh
```

写入 `CLAUDE.md` 的好处：下次运行 `/health` 时直接读取，跳过检测流程，节省时间。

---

## Step 2：运行工具（第 616-637 行）

> **原文**：
> ```
> Run each detected tool. For each tool:
> 1. Record the start time
> 2. Run the command, capturing both stdout and stderr
> 3. Record the exit code
> 4. Record the end time
> 5. Capture the last 50 lines of output for the report
> ```

**中文**：运行每个检测到的工具。对每个工具：记录开始时间、运行命令（捕获 stdout 和 stderr）、记录退出码、记录结束时间、捕获最后 50 行输出用于报告。

```bash
# 每个工具的运行模板
START=$(date +%s)
tsc --noEmit 2>&1 | tail -50
EXIT_CODE=$?
END=$(date +%s)
echo "TOOL:typecheck EXIT:$EXIT_CODE DURATION:$((END-START))s"
```

**关键设计点**：

1. **顺序执行，不并行**："Run tools sequentially (some may share resources or lock files)." 某些工具（如 tsc）会占用文件锁，并行会冲突。
2. **tail -50**：只保留最后 50 行。完整输出可能有几千行，只需要摘要。
3. **区分 SKIPPED 和 FAILED**："If a tool is not installed or not found, record it as `SKIPPED` with reason, not as a failure." 没装 shellcheck 不等于 shell 有问题。

---

## Step 3：评分系统（第 640-666 行）

这是 `/health` 的核心算法——加权复合评分。

### 评分矩阵

> **原文**：
> ```
> | Category | Weight | 10 | 7 | 4 | 0 |
> |-----------|--------|------|-----------|------------|-----------|
> | Type check | 25% | Clean (exit 0) | <10 errors | <50 errors | >=50 errors |
> | Lint | 20% | Clean (exit 0) | <5 warnings | <20 warnings | >=20 warnings |
> | Tests | 30% | All pass (exit 0) | >95% pass | >80% pass | <=80% pass |
> | Dead code | 15% | Clean (exit 0) | <5 unused exports | <20 unused | >=20 unused |
> | Shell lint | 10% | Clean (exit 0) | <5 issues | >=5 issues | N/A (skip) |
> ```

| 维度 | 权重 | 评分 10 | 评分 7 | 评分 4 | 评分 0 |
|------|------|---------|--------|--------|--------|
| 类型检查 | **25%** | 零错误（exit 0）| <10 个错误 | <50 个错误 | ≥50 个错误 |
| Lint | **20%** | 零警告（exit 0）| <5 个警告 | <20 个警告 | ≥20 个警告 |
| 测试 | **30%** | 全部通过（exit 0）| >95% 通过 | >80% 通过 | ≤80% 通过 |
| 死代码 | **15%** | 零未用导出 | <5 个未用 | <20 个未用 | ≥20 个未用 |
| Shell lint | **10%** | 零问题 | <5 个问题 | ≥5 个问题 | N/A（跳过）|

### 复合分公式

```
composite = (typecheck × 0.25) + (lint × 0.20) + (test × 0.30)
          + (deadcode × 0.15) + (shell × 0.10)
```

**示例计算**：
```
Type check:  10 × 0.25 = 2.50
Lint:         8 × 0.20 = 1.60
Tests:       10 × 0.30 = 3.00
Dead code:    7 × 0.15 = 1.05
Shell lint:  10 × 0.10 = 1.00
             ─────────────────
COMPOSITE:              = 9.15  → 显示为 9.1
```

### 权重设计原理

为什么这样分配权重？

```
Tests (30%)  ──── 最高权重
  原因：测试直接验证功能正确性。没有测试 = 不知道代码能不能工作。
  这是"你的用户会不会遇到 bug"的代理指标。

Type check (25%)  ──── 第二高
  原因：类型错误是编译期能发现的 bug。TypeScript 的价值就在这。
  100 个类型错误的代码库几乎肯定有运行时问题。

Lint (20%)  ──── 中等权重
  原因：Lint 捕获代码风格和常见反模式，但不直接等于 bug。
  重要，但 lint clean 不代表代码正确。

Dead code (15%)  ──── 较低权重
  原因：未用导出是技术债，不是直接 bug。但积累会让代码库变臃肿。

Shell lint (10%)  ──── 最低权重
  原因：不是所有项目都有 shell 脚本。权重低确保它不会主导总分。
```

### 跳过维度时的权重重分配

> **原文**：
> ```
> If a category is skipped (tool not available), redistribute its weight proportionally
> among the remaining categories.
> ```

**示例**：如果 shell lint 被跳过（权重 10%），其余 4 项按比例重分配：
```
原权重：TC=25%, Lint=20%, Test=30%, Dead=15%, Shell=10%
去掉 Shell 后各项总和 = 90%
重分配：TC=27.8%, Lint=22.2%, Test=33.3%, Dead=16.7%
```

这确保分母始终是 100%，分数有意义。

### 工具输出解析规则

> **原文**：
> ```
> - tsc: Count lines matching `error TS` in output.
> - biome/eslint/ruff: Count lines matching error/warning patterns.
> - Tests: Parse pass/fail counts from the test runner output.
> - knip: Count lines reporting unused exports, files, or dependencies.
> - shellcheck: Count distinct findings (lines starting with "In ... line").
> ```

| 工具 | 计数方式 | 示例模式 |
|------|----------|----------|
| tsc | 匹配 `error TS` 行数 | `error TS2345: Argument of type 'string'` |
| biome/eslint/ruff | 匹配 error/warning 模式或摘要行 | `✖ 3 errors, 2 warnings found` |
| pytest/bun test | 解析 pass/fail 计数 | `47 passed, 2 failed` |
| knip | 未使用导出/文件/依赖的行数 | `Unused exports (4): src/utils.ts` |
| shellcheck | 以 "In ... line" 开头的行数 | `In script.sh line 12:` |

---

## Step 4：呈现仪表盘（第 669-708 行）

### 仪表盘格式

> **原文**：
> ```
> CODE HEALTH DASHBOARD
> =====================
>
> Project: <project name>
> Branch:  <current branch>
> Date:    <today>
>
> Category      Tool              Score   Status     Duration   Details
> ----------    ----------------  -----   --------   --------   -------
> Type check    tsc --noEmit      10/10   CLEAN      3s         0 errors
> Lint          biome check .      8/10   WARNING    2s         3 warnings
> Tests         bun test          10/10   CLEAN      12s        47/47 passed
> Dead code     knip               7/10   WARNING    5s         4 unused exports
> Shell lint    shellcheck        10/10   CLEAN      1s         0 issues
>
> COMPOSITE SCORE: 9.1 / 10
>
> Duration: 23s total
> ```

**状态标签映射**：

| 分数范围 | 状态标签 | 含义 |
|---------|---------|------|
| 10 | `CLEAN` | 完美通过 |
| 7-9 | `WARNING` | 有小问题，可接受 |
| 4-6 | `NEEDS WORK` | 需要处理 |
| 0-3 | `CRITICAL` | 严重问题，优先修复 |

### 低分细节展示

当某维度低于 7 分时，展示具体问题：

```
DETAILS: Lint (3 warnings)
  biome check . output:
    src/utils.ts:42 — lint/complexity/noForEach: Prefer for...of
    src/api.ts:18 — lint/style/useConst: Use const instead of let
    src/api.ts:55 — lint/suspicious/noExplicitAny: Unexpected any
```

**设计原理**：精确到文件名和行号。不是"有 3 个警告"——是"src/api.ts:55 有一个 any 类型"。这样用户不需要自己再跑工具，直接去修就行。

---

## Step 5：持久化到健康历史（第 712-732 行）

### JSONL 历史文件

```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)" && mkdir -p ~/.gstack/projects/$SLUG
```

每次运行追加一行到 `~/.gstack/projects/$SLUG/health-history.jsonl`：

```json
{"ts":"2026-03-31T14:30:00Z","branch":"main","score":9.1,"typecheck":10,"lint":8,"test":10,"deadcode":7,"shell":10,"duration_s":23}
```

**字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `ts` | ISO 8601 字符串 | 运行时间戳 |
| `branch` | 字符串 | 当前 git 分支 |
| `score` | 浮点数（1位小数）| 复合分 |
| `typecheck` | 整数 0-10 | 类型检查分，跳过时为 `null` |
| `lint` | 整数 0-10 | Lint 分 |
| `test` | 整数 0-10 | 测试分 |
| `deadcode` | 整数 0-10 | 死代码分 |
| `shell` | 整数 0-10 | Shell lint 分 |
| `duration_s` | 整数 | 所有工具总耗时（秒）|

### JSONL 格式的优势

JSONL（每行一个 JSON 对象）是追踪历史数据的理想格式：
- **追加友好**：`echo '...' >> file.jsonl` 无需解析整个文件
- **流式读取**：`tail -10 file.jsonl` 取最近 10 条，O(1)
- **grep 友好**：`grep '"branch":"main"'` 过滤特定分支
- **无锁**：多个进程并发追加不会损坏文件

---

## Step 6：趋势分析 + 建议（第 735-801 行）

### 趋势追踪

读取最近 10 条历史记录：

```bash
tail -10 ~/.gstack/projects/$SLUG/health-history.jsonl 2>/dev/null || echo "NO_HISTORY"
```

**有历史数据时显示趋势表**：

```
HEALTH TREND (last 5 runs)
==========================
Date          Branch         Score   TC   Lint  Test  Dead  Shell
----------    -----------    -----   --   ----  ----  ----  -----
2026-03-28    main           9.4     10   9     10    8     10
2026-03-29    feat/auth      8.8     10   7     10    7     10
2026-03-30    feat/auth      8.2     10   6     9     7     10
2026-03-31    feat/auth      9.1     10   8     10    7     10

Trend: IMPROVING (+0.9 since last run)
```

**趋势判断逻辑**：
- `score_current > score_prev` → `IMPROVING (+X.X)`
- `score_current < score_prev` → `DECLINING (-X.X)`
- `score_current == score_prev` → `STABLE`

### 回归检测

> **原文**：
> ```
> If score dropped vs the previous run:
> 1. Identify WHICH categories declined
> 2. Show the delta for each declining category
> 3. Correlate with tool output -- what specific errors/warnings appeared?
> ```

```
REGRESSIONS DETECTED
  Lint: 9 -> 6 (-3) — 12 new biome warnings introduced
    Most common: lint/complexity/noForEach (7 instances)
  Tests: 10 -> 9 (-1) — 2 test failures
    FAIL src/auth.test.ts > should validate token expiry
    FAIL src/auth.test.ts > should reject malformed JWT
```

**关键**：不只说"分数下降了"——要说"哪些文件、哪些具体问题"。这才是有用的信息。

### 建议优先级算法

> **原文**：
> ```
> Prioritize suggestions by impact (weight * score deficit):
> Rank by `weight * (10 - score)` descending. Only show categories below 10.
> ```

**示例计算**（score: typecheck=10, lint=6, test=9, deadcode=7, shell=10）：

```
优先级分 = weight × (10 - score)

Tests(9):    0.30 × (10-9)  = 0.30  → [HIGH] 因为权重最大
Lint(6):     0.20 × (10-6)  = 0.80  → [HIGH] 因为分差大
Dead(7):     0.15 × (10-7)  = 0.45  → [MED]
Typecheck/Shell = 0（已是满分，不显示）

排序结果：Lint(0.80) > Dead(0.45) > Tests(0.30)
```

**输出格式**：

```
RECOMMENDATIONS (by impact)
============================
1. [HIGH]  Address 12 lint warnings (Lint: 6/10, weight 20%)
   Run: biome check . --write to auto-fix
2. [MED]   Remove 4 unused exports (Dead code: 7/10, weight 15%)
   Run: knip --fix to auto-remove
3. [LOW]   Fix 1 failing test (Tests: 9/10, weight 30%)
   Run: bun test --verbose to see failures
```

---

## 核心设计原则（第 793-801 行）

> **原文**：
> ```
> 1. Wrap, don't replace. Run the project's own tools. Never substitute your own
>    analysis for what the tool reports.
> 2. Read-only. Never fix issues. Present the dashboard and let the user decide.
> 3. Respect CLAUDE.md. If `## Health Stack` is configured, use those exact commands.
> 4. Skipped is not failed. If a tool isn't available, skip it gracefully.
> 5. Show raw output for failures. When a tool reports errors, include the actual output.
> 6. Trends require history. On first run, say "First health check -- no trend data yet."
> 7. Be honest about scores. A codebase with 100 type errors and all tests passing is not healthy.
> ```

**逐条解析**：

**规则 1：包装，不替代（Wrap, don't replace）**

```
错误做法：AI 自己扫描代码，说"我看到有 3 个 any 类型"
正确做法：运行 tsc --noEmit，报告 tsc 的输出

原因：tsc 的规则库有几千条，AI 无法复现。
      你的工具才是权威来源，AI 只是执行者。
```

**规则 2：只读不改（Read-only）**

见上文 HARD GATE 分析。核心是"诊断 vs 治疗"职责分离。

**规则 3：尊重配置（Respect CLAUDE.md）**

```
CLAUDE.md 中的 ## Health Stack 是团队约定的配置。
如果团队决定用 pytest 不用 unittest，就用 pytest，不要自作主张。
"配置即文档"——让 CLAUDE.md 成为团队一致的依据。
```

**规则 4：跳过不等于失败（Skipped is not failed）**

```
没有 shellcheck？→ SKIPPED（不计入，重分配权重）
有 shellcheck 但报告 5 个问题？→ NEEDS WORK

区别很重要：
- 工具不存在 ≠ 代码有问题
- 工具运行但报错 = 代码有问题
```

**规则 5：展示原始输出**

用户需要原始输出才能行动。"有 3 个 lint 警告"没用。"src/api.ts:55 有一个 any 类型"才有用。

**规则 6：第一次运行没有趋势**

```
"First health check -- no trend data yet.
 Run /health again after making changes to track progress."
```

诚实告知用户，不要凭空捏造趋势。

**规则 7：分数要诚实**

```
100 个类型错误 + 全测试通过 ≠ 健康代码库

composite = 0×0.25 + 10×0.30 + ... ≈ 5.x

分数要反映现实。不能因为测试全通过就忽视 100 个类型错误。
```

---

## /health 与其他技能的对比

### /health vs /qa

```
                    /health                    /qa
目标           代码质量审计              功能正确性测试
方法           运行静态分析工具          运行 app + 交互测试
工具           tsc, eslint, knip        浏览器（$B 命令）
输入           源代码                   运行中的 web app
输出           质量仪表盘               bug 报告
修复？         否（HARD GATE）          是（迭代修复）
触发词         "health check"           "test the site", "find bugs"
何时运行       持续集成 / 代码审查前    功能开发后 / 部署前
```

### /health vs /review

```
                    /health                    /review（PR 审查）
范围           整个代码库                当前 diff
时机           随时                      PR 合并前
关注点         全局质量分数              具体变更的问题
历史追踪       是（JSONL）               是（branch-reviews.jsonl）
修复？         否                        有时会指出需要修复的点
```

### /health vs CI 系统

```
                    /health                    GitHub Actions / CI
运行环境       Claude 对话中             独立 CI 服务器
触发方式       手动（/health）           自动（push/PR）
输出           自然语言仪表盘            日志 + 状态徽章
趋势追踪       本地 JSONL               CI 平台历史记录
修复建议       是（带优先级）            否（只报告）
```

---

## CLAUDE.md 中的 Health Stack 配置完整参考

```markdown
## Health Stack

- typecheck: tsc --noEmit
- lint: biome check .
- test: bun test
- deadcode: knip
- shell: shellcheck *.sh scripts/*.sh bin/*.sh
```

**各字段含义**：

| 键 | 对应维度 | 权重 |
|----|----------|------|
| `typecheck` | Type check | 25% |
| `lint` | Lint | 20% |
| `test` | Tests | 30% |
| `deadcode` | Dead code | 15% |
| `shell` | Shell lint | 10% |

**自定义示例**（Python 项目）：
```markdown
## Health Stack

- typecheck: mypy src/
- lint: ruff check .
- test: pytest --tb=short
- deadcode: vulture src/
```

**自定义示例**（Go 项目）：
```markdown
## Health Stack

- typecheck: go vet ./...
- lint: golangci-lint run
- test: go test ./...
```

---

## 完整工作流图

```
用户输入 /health
      |
      ↓
[Preamble] 环境初始化
  - 版本检查
  - 会话记录
  - 路由规则检查
      |
      ↓
[Step 1] 检测 Health Stack
  CLAUDE.md 有配置?
  |── YES ──→ 使用配置命令
  |── NO  ──→ 自动检测
                |
                ↓
           AskUserQuestion（确认工具）
                |
               A/B ──→ 写入 CLAUDE.md
               C    ──→ 直接运行
      |
      ↓
[Step 2] 顺序运行每个工具
  tsc --noEmit
  biome check .
  bun test
  knip
  shellcheck
  (记录: 退出码, 耗时, 最后50行输出)
      |
      ↓
[Step 3] 评分
  每个维度 0-10 打分
  计算复合分（加权）
  跳过项 → 重分配权重
      |
      ↓
[Step 4] 呈现仪表盘
  CODE HEALTH DASHBOARD
  5维度表格 + 状态标签
  复合分
  低分细节（文件名+行号）
      |
      ↓
[Step 5] 持久化历史
  追加 JSONL 到
  ~/.gstack/projects/$SLUG/health-history.jsonl
      |
      ↓
[Step 6] 趋势分析
  读取最近10条历史
  有历史? → 显示趋势表 + 回归检测
  无历史? → "First health check"
      |
      ↓
[建议] 按 weight×(10-score) 排序
  只显示分数低于 10 的维度
  给出具体命令
      |
      ↓
[HARD GATE] 停止，不修复任何代码
      |
      ↓
[Telemetry] 记录运行结果
```

---

## 使用场景快速参考

**什么时候运行 `/health`？**

1. **代码审查前** — 快速确认 CI 会不会挂掉
2. **功能开发后** — 看看引入了多少技术债
3. **每周例行** — 追踪代码库健康趋势
4. **新成员入职** — 了解项目当前质量状态
5. **重构后** — 确认没有引入新问题

**第一次运行时的期望**：
```
1. 检测工具（30秒）
2. 确认工具（AskUserQuestion）
3. 运行所有工具（取决于项目大小，通常 30-120 秒）
4. 看到仪表盘
5. "First health check -- no trend data yet."
6. 工具配置写入 CLAUDE.md
```

**后续运行（已有配置）**：
```
1. 直接读取 CLAUDE.md 配置（跳过检测）
2. 运行所有工具
3. 看到仪表盘 + 趋势对比
```

---

## 历史文件结构

```
~/.gstack/
└── projects/
    └── my-app/                          # 项目 slug（由 gstack-slug 生成）
        ├── health-history.jsonl         # 健康历史（每行一次运行）
        ├── learnings.jsonl              # 操作学习记录
        ├── timeline.jsonl              # 技能运行时间线
        └── checkpoints/               # /checkpoint 技能的存档
```

**health-history.jsonl 示例内容**：
```jsonl
{"ts":"2026-03-28T10:00:00Z","branch":"main","score":9.4,"typecheck":10,"lint":9,"test":10,"deadcode":8,"shell":10,"duration_s":18}
{"ts":"2026-03-29T14:30:00Z","branch":"feat/auth","score":8.8,"typecheck":10,"lint":7,"test":10,"deadcode":7,"shell":10,"duration_s":22}
{"ts":"2026-03-30T09:15:00Z","branch":"feat/auth","score":8.2,"typecheck":10,"lint":6,"test":9,"deadcode":7,"shell":10,"duration_s":25}
{"ts":"2026-03-31T14:30:00Z","branch":"feat/auth","score":9.1,"typecheck":10,"lint":8,"test":10,"deadcode":7,"shell":10,"duration_s":23}
```

从这个文件可以清楚看到：3 月 29-30 日 lint 从 9 降到 6（feat/auth 分支引入了质量问题），31 日修复后回升到 8。测试在 30 日也降了 1 分，然后恢复。这就是趋势追踪的价值。

---

## 与 gstack 生态的关系

```
                    /health
                       |
          ┌────────────┼────────────┐
          |            |            |
        读取          写入         建议跑
       CLAUDE.md    JSONL         其他技能
          |
    ## Health Stack 配置
          |
    ┌─────┴─────┐
    |           |
  已配置      未配置
    |           |
  直接用      自动检测
              + 写入配置

/health 发现严重问题后，用户可能需要：
  - /investigate  → 调查具体 bug 根因
  - /qa           → 功能测试（/health 的测试是单元测试，/qa 是集成测试）
  - /review       → 在 PR 合并前再次确认
```

**总结**：`/health` 是 CI 仪表盘的 AI 版本。它的职责边界非常清晰——诊断，不治疗。通过加权复合评分和趋势追踪，它让"代码库健康"从模糊的感觉变成可量化的数字，让团队能够做出数据驱动的技术债决策。
