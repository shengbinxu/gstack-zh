# `/retro` 技能逐段中英对照注解

> 对应源文件：[`retro/SKILL.md`](https://github.com/garrytan/gstack/blob/main/retro/SKILL.md)（约 1468 行，含 Preamble 展开）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: retro
preamble-tier: 2
version: 2.0.0
description: |
  Weekly engineering retrospective. Analyzes commit history, work patterns,
  and code quality metrics with persistent history and trend tracking.
  Team-aware: breaks down per-person contributions with praise and growth areas.
  Use when asked to "weekly retro", "what did we ship", or "engineering retrospective".
  Proactively suggest at the end of a work week or sprint. (gstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
---
```

**中文翻译**：

- **name**: 技能名称，用户输入 `/retro` 触发。
- **preamble-tier: 2**: Preamble 详细度级别 2。包含会话管理、遥测、语音风格、上下文恢复，但不包含 tier 3/4 的 Repo 模式检测和 Search Before Building。
- **version: 2.0.0**: 大版本迭代，说明跨会话历史追踪和团队成员分析是后来加入的重大功能。
- **description**: 周工程复盘。分析 commit 历史、工作模式、代码质量指标，持久化历史并追踪趋势。团队感知：按人拆分贡献，含表扬和成长建议。
- **allowed-tools**: 注意**没有 Edit**——retro 只读取和写分析快照，不修改源代码。没有 Grep——commit 分析完全通过 Bash 的 `git log` 完成。

> **设计原理：为什么不用 Grep？**
> retro 的数据源是 git 历史，不是代码内容。`git log` 系列命令天然支持时间窗口、作者过滤、格式化输出，比 Grep 更适合这个场景。Grep 用于搜索代码内容，不用于分析 commit 流。

---

## {{PREAMBLE}} 展开区

原文 Preamble 在运行时展开为约 500 行的前置上下文（tier 2）。`retro` 的 Preamble 包含以下模块：

### 1. 会话跟踪与升级检查

```bash
_UPD=$(~/.claude/skills/gstack/bin/gstack-update-check 2>/dev/null || true)
mkdir -p ~/.gstack/sessions
touch ~/.gstack/sessions/"$PPID"
_SESSIONS=$(find ~/.gstack/sessions -mmin -120 -type f 2>/dev/null | wc -l | tr -d ' ')
```

**作用**：检查 gstack 是否有新版本可升级；记录当前会话（以父进程 PID 为 key）；统计过去 120 分钟内的活跃会话数；清理过期会话文件。

> **设计原理：用文件系统做会话注册**
> `~/.gstack/sessions/` 目录中每个文件代表一个活跃会话，文件名是进程 PID。`find -mmin -120` 找出 2 小时内被访问的文件即为活跃会话。简单、无依赖、跨 shell 兼容。

### 2. 配置读取与环境探测

```bash
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_PROACTIVE=$(~/.claude/skills/gstack/bin/gstack-config get proactive 2>/dev/null || echo "true")
_SKILL_PREFIX=$(~/.claude/skills/gstack/bin/gstack-config get skill_prefix 2>/dev/null || echo "false")
source <(~/.claude/skills/gstack/bin/gstack-repo-mode 2>/dev/null) || true
```

**作用**：读取当前 git 分支、主动模式开关、技能前缀设置、仓库模式（solo/team）。

### 3. 遥测初始化

```bash
_TEL_START=$(date +%s)
_SESSION_ID="$$-$(date +%s)"
if [ "$_TEL" != "off" ]; then
  echo '{"skill":"retro","ts":"...","repo":"..."}' >> ~/.gstack/analytics/skill-usage.jsonl
fi
```

**作用**：记录技能启动时间戳（用于最终计算耗时）；生成唯一会话 ID；在遥测开启时记录技能使用事件到本地 JSONL 文件。

### 4. 渐进式首次引导

Preamble 包含四个一次性引导流程，每个都有"已完成"标记文件防止重复触发：

| 引导项 | 标记文件 | 触发条件 |
|--------|----------|----------|
| Boil the Lake 哲学介绍 | `~/.gstack/.completeness-intro-seen` | `LAKE_INTRO=no` |
| 遥测偏好询问 | `~/.gstack/.telemetry-prompted` | `TEL_PROMPTED=no` |
| 主动模式偏好询问 | `~/.gstack/.proactive-prompted` | `PROACTIVE_PROMPTED=no` |
| CLAUDE.md 路由规则注入 | `HAS_ROUTING=yes` | 三个前置条件都满足 |

> **设计原理：渐进式 onboarding**
> 不在第一次运行时一次性问完所有问题。先介绍哲学，再问遥测，再问主动模式，再注入路由规则。每步都有状态文件记录，不会重复打扰。这是 CLI 工具 onboarding 的最佳实践。

### 5. 上下文恢复（Context Recovery）

```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
_PROJ="${GSTACK_HOME:-$HOME/.gstack}/projects/${SLUG:-unknown}"
find "$_PROJ/ceo-plans" "$_PROJ/checkpoints" -type f -name "*.md" 2>/dev/null | xargs ls -t | head -3
```

**作用**：在会话压缩（compaction）后恢复上下文。扫描该项目最近的 CEO 计划文件和 checkpoint 文件，读取最新的一个，还原之前的工作状态。

> **设计原理：对抗上下文窗口遗忘**
> Claude 的上下文窗口有限。长会话中，早期的决策和计划会被"压缩"丢失。Context Recovery 通过写入持久化文件（不依赖对话历史），让 AI 在会话恢复时能重建完整的工作状态。这是 `/checkpoint` 技能的基础机制，`/retro` 也复用了它。

---

## 技能核心声明

> **原文**：
> ```
> # /retro — Weekly Engineering Retrospective
>
> Generates a comprehensive engineering retrospective analyzing commit history,
> work patterns, and code quality metrics. Team-aware: identifies the user running
> the command, then analyzes every contributor with per-person praise and growth
> opportunities. Designed for a senior IC/CTO-level builder using Claude Code as
> a force multiplier.
> ```

**中文**：生成全面的工程复盘，分析 commit 历史、工作模式、代码质量指标。团队感知：识别运行命令的用户，然后分析每个贡献者，提供逐人表扬和成长机会。设计对象是使用 Claude Code 作为效能倍增器的高级工程师/CTO 级别开发者。

> **设计原理："效能倍增器"定位**
> retro 不是给项目经理看的进度汇报。它是给技术负责人看的工程信号仪表盘。目标是让一个人做出原本需要一个团队才能做的工程质量监控工作。

---

## 参数解析

> **原文**：
> ```
> ## Arguments
> - /retro         — default: last 7 days
> - /retro 24h     — last 24 hours
> - /retro 14d     — last 14 days
> - /retro 30d     — last 30 days
> - /retro compare — compare current window vs prior same-length window
> - /retro compare 14d — compare with explicit window
> - /retro global  — cross-project retro across all AI coding tools (7d default)
> - /retro global 14d — cross-project retro with explicit window
> ```

**中文**：支持 4 种参数形式：
1. 时间窗口（`24h`/`14d`/`30d`）
2. 比较模式（`compare`）：当前窗口 vs 上一个同等长度窗口
3. 全局模式（`global`）：跨所有项目的跨仓库复盘
4. 无参数：默认 7 天

> **设计原理：全局模式的价值**
> `/retro global` 是大版本迭代（v2.0.0）引入的核心特性。很多开发者同时维护多个项目（主业 + 开源 + 副业）。单仓库的复盘只能看一个项目。全局模式聚合所有 git 仓库，给出跨项目的真实生产力图景——比如发现"这周 70% 时间花在 gstack 上，主项目只有 3 次 commit"。

---

## 时间窗口处理机制

> **原文**：
> ```
> Midnight-aligned windows: For day (d) and week (w) units, compute an absolute
> start date at local midnight, not a relative string. For example, if today is
> 2026-03-18 and the window is 7 days: the start date is 2026-03-11. Use
> --since="2026-03-11T00:00:00" for git log queries — the explicit T00:00:00
> suffix ensures git starts from midnight. Without it, git uses the current
> wall-clock time (e.g., --since="2026-03-11" at 11pm means 11pm, not midnight).
> ```

**中文**：日/周单位必须计算**绝对午夜对齐日期**，而不是相对字符串。`--since="7 days ago"` 会因为执行时间不同而产生不一致的结果（中午跑和晚上跑包含的 commit 数量不同）。`--since="2026-03-11T00:00:00"` 确保每次都从午夜开始，结果稳定可复现。

```
错误：git log --since="7 days ago"   # 相对时间，结果因执行时刻而异
正确：git log --since="2026-03-11T00:00:00"  # 绝对时间，结果稳定
```

> **设计原理：可重现性是度量的基础**
> 如果两次运行同一个命令结果不同，趋势分析就没有意义。午夜对齐让"本周"的定义稳定——无论你在周五下午还是周日晚上跑 retro，"本周 7 天"的边界都是一样的。

---

## 跨项目学习机制

> **原文**：
> ```
> ## Prior Learnings
> Search for relevant learnings from previous sessions:
>
> if [ "$_CROSS_PROJ" = "true" ]; then
>   ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 10 --cross-project
> else
>   ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 10
> fi
> ```

**中文**：在开始分析之前，先搜索过去会话中记录的"学习条目"（learnings）。分为两种模式：仅当前项目（默认）或跨所有项目（需开启 `cross_project_learnings`）。

> **设计原理：知识的复利**
> 每次 retro 完成后，AI 会把发现的模式和坑记录到 `learnings.jsonl`。下次运行时，这些记录会被检索并应用到分析中。用户看到的不只是这次分析的结果，还有历次分析的积累。原文这样描述这个机制的价值：*"This makes the compounding visible."*（让复利变得可见。）

---

## Step 1：数据采集（并行执行）

> **原文**：
> ```
> Run ALL of these git commands in parallel (they are independent):
>
> # 1. 提交元数据 + 统计
> git log origin/<default> --since="<window>" --format="%H|%aN|%ae|%ai|%s" --shortstat
>
> # 2. 每个 commit 的测试 vs 生产代码行数
> git log origin/<default> --since="<window>" --format="COMMIT:%H|%aN" --numstat
>
> # 3. 提交时间戳（用于会话检测和小时分布）
> git log origin/<default> --since="<window>" --format="%at|%aN|%ai|%s" | sort -n
>
> # 4. 最频繁变更的文件（热点分析）
> git log origin/<default> --since="<window>" --format="" --name-only | grep -v '^$' | sort | uniq -c | sort -rn
>
> # 5-12. ...（PR 编号、作者文件热点、gstack 遥测等）
> ```

**中文**：12 条 git 命令**并行运行**（因为彼此独立），从 origin 的 default 分支（而非本地分支）读取数据，避免本地 stale 数据。

这 12 条命令分别采集：

| 编号 | 采集内容 | 用于步骤 |
|------|----------|----------|
| 1 | 提交元数据 + 变更行数 | Step 2 摘要表格 |
| 2 | 每 commit 的测试/生产 LOC | 测试比例计算 |
| 3 | 时间戳序列（已排序） | 会话检测、小时分布 |
| 4 | 文件变更频率 | 热点分析 |
| 5 | PR/MR 编号 | 合并 PR 统计 |
| 6 | 作者-文件关联 | 团队负责区域分析 |
| 7 | 作者提交次数 | 排行榜 |
| 8 | Greptile 历史 | 代码审查信号比率 |
| 9 | TODOS.md 积压 | 待办健康状况 |
| 10-12 | 测试文件计数、回归测试 commit、gstack 使用遥测 | 测试健康 |

> **设计原理：使用 origin 而非本地分支**
> `git log origin/<default>` 而不是 `git log main`——这一点至关重要。本地 main 可能落后于远端几十个 commit。retro 要分析的是"团队这周实际合并到主线的代码"，不是你本地的快照。

---

## Step 2：指标计算

> **原文**：
> ```
> | Metric              | Value |
> |---------------------|-------|
> | Commits to main     | N     |
> | Contributors        | N     |
> | PRs merged          | N     |
> | Total insertions    | N     |
> | Total deletions     | N     |
> | Net LOC added       | N     |
> | Test LOC (insertions)| N    |
> | Test LOC ratio      | N%    |
> | ...                 |       |
>
> Then show a per-author leaderboard immediately below:
> Contributor         Commits   +/-          Top area
> You (garry)              32   +2400/-300   browse/
> alice                    12   +800/-150    app/services/
> ```

**中文**：计算所有核心指标后，立即展示**按提交数降序的贡献者排行榜**。当前用户（通过 `git config user.name` 识别）始终出现在第一位，标注为"You (name)"。

> **设计原理："You First" 叙事策略**
> retro 的主要受众是运行命令的那个人。把自己的数据放在最前面，符合人类的阅读习惯：先看自己的，再看团队的。整个 retro 的叙事结构都围绕这个原则：先给出"你"的深度分析，再给每个队友的简短分析。

---

## Step 3 & 4：时间分布与会话检测

> **原文**：
> ```
> ### Step 3: Commit Time Distribution
> Show hourly histogram in local time using bar chart:
> Hour  Commits
>  00:    4      ████
>  07:    5      █████
>
> ### Step 4: Work Session Detection
> Detect sessions using 45-minute gap threshold between consecutive commits.
> Classify sessions:
> - Deep sessions (50+ min)
> - Medium sessions (20-50 min)
> - Micro sessions (<20 min, typically single-commit fire-and-forget)
> ```

**中文**：
- **Step 3**：用 ASCII 柱状图展示小时级提交分布，识别峰值时段、死区、双峰模式（早晨+晚上）、深夜编码集群（22点后）。
- **Step 4**：以**45分钟间隔**作为会话边界——连续两次 commit 相差超过 45 分钟，视为两个独立会话。

```
会话检测示意：
09:00 commit A ─┐
09:15 commit B  ├── Session 1 (30min, micro)
09:30 commit C ─┘

(间隔 70 分钟)

10:40 commit D ─┐
11:20 commit E  │
12:05 commit F  ├── Session 2 (85min, deep)
12:25 commit G ─┘
```

> **设计原理：45 分钟阈值的由来**
> 45 分钟是一个平衡值：短于番茄工作法（25min）会将正常的思考暂停也切割成多个会话；长于一个典型的午饭时间（60min）会将午饭前后的工作合并为一个会话。45 分钟能正确识别"同一个问题的持续工作时段"。

---

## Step 5 & 6：提交类型分析与热点文件

> **原文**：
> ```
> ### Step 5: Commit Type Breakdown
> Categorize by conventional commit prefix (feat/fix/refactor/test/chore/docs).
> Show as percentage bar:
> feat:     20  (40%)  ████████████████████
> fix:      27  (54%)  ███████████████████████████
>
> Flag if fix ratio exceeds 50% — this signals a "ship fast, fix fast" pattern
> that may indicate review gaps.
>
> ### Step 6: Hotspot Analysis
> Show top 10 most-changed files. Flag files changed 5+ times (churn hotspots).
> ```

**中文**：
- **Step 5**：按 Conventional Commits 规范分类。fix 比例超过 50% 是一个信号：可能存在评审不足、发布后追修的模式。
- **Step 6**：热点文件（变更次数 ≥5）往往是架构不稳定或边界模糊的信号。频繁变更的 `VERSION`/`CHANGELOG` 则是版本纪律的正向指标。

| 提交类型比例 | 解读 |
|------------|------|
| feat > 50% | 功能主导期，团队在高速扩展能力 |
| fix > 50% | 质量债务信号，可能需要更多评审或测试 |
| refactor > 20% | 主动还债，通常是健康信号 |
| chore > 30% | 大量维护工作，可能是工具链整理期 |

---

## Step 7 & 8：PR 规模与焦点分数

> **原文**：
> ```
> ### Step 7: PR Size Distribution
> - Small (<100 LOC)
> - Medium (100-500 LOC)
> - Large (500-1500 LOC)
> - XL (1500+ LOC)
>
> ### Step 8: Focus Score + Ship of the Week
> Focus score: Calculate the percentage of commits touching the single
> most-changed top-level directory.
> ```

**中文**：
- **Step 7**：PR 规模分布反映发布节奏。大量 XL PR 通常意味着功能颗粒度太粗，评审质量会下降。
- **Step 8**：焦点分数 = 最高频变更目录的 commit 比例。例如"62% (app/services/)"表示这周 62% 的工作集中在 services 目录，专注度较高。

> **设计原理：焦点分数的意义**
> 上下文切换是效率杀手。一个工程师这周在 5 个不同模块各改了几次，和另一个工程师把精力集中在一个模块做深做透，产出的质量是截然不同的。焦点分数让这种差异可见。

---

## Step 9：团队成员分析（核心功能）

> **原文**：
> ```
> For each contributor (including the current user), compute:
> 1. Commits and LOC
> 2. Areas of focus
> 3. Commit type mix
> 4. Session patterns
> 5. Test discipline
> 6. Biggest ship
>
> For the current user ("You"): This section gets the deepest treatment.
>
> For each teammate:
> - Praise (1-2 specific things): Not "great work" — say exactly what was good.
> - Opportunity for growth (1 specific thing): Frame as leveling-up, not criticism.
> ```

**中文**：这是 retro 的灵魂部分。要求：

1. **"You" 部分**：最深度分析，包含所有细节，用第一人称叙述（"Your peak hours..."）。
2. **队友部分**：每人 2-3 句概括，然后给出**锚定在实际 commit 上的**表扬（1-2 条）和成长建议（1 条）。

> **设计原理：表扬必须具体**
> 原文要求表扬要具体："Anchor in actual commits. Not 'great work' — say exactly what was good."（锚定在实际 commit 上，不要说"干得好"，要说清楚好在哪里。）
>
> 泛泛的"great job"是信息量为零的噪音。"Shipped the entire auth middleware rewrite in 3 focused sessions with 45% test coverage"（在 3 个专注会话中完成整个 auth 中间件重写，并保持 45% 测试覆盖率）才是真正有意义的反馈，会让人觉得自己被认真看到了。

### AI 协作追踪

> **原文**：
> ```
> If many commits have Co-Authored-By AI trailers (e.g., Claude, Copilot),
> note the AI-assisted commit percentage as a team metric. Frame it neutrally —
> "N% of commits were AI-assisted" — without judgment.
> ```

**中文**：解析 commit message 中的 `Co-Authored-By:` 尾注。AI 协作者（如 `noreply@anthropic.com`）不算作团队成员，但"AI 辅助提交占比"作为独立指标展示。不做价值判断——这是客观数据。

---

## Step 10-12：趋势、连续天数、历史比较

> **原文**：
> ```
> ### Step 11: Streak Tracking
> Count consecutive days with at least 1 commit to origin/<default>.
> - "Team shipping streak: 47 consecutive days"
> - "Your shipping streak: 32 consecutive days"
>
> ### Step 12: Load History & Compare
> If prior retros exist, show Trends vs Last Retro table:
>                     Last        Now         Delta
> Test ratio:         22%    →    41%         ↑19pp
> Fix ratio:          54%    →    30%         ↓24pp (improving)
> ```

**中文**：
- **Step 10**（≥14天窗口）：按周分桶展示趋势，让"方向"可见。
- **Step 11**：连续发货天数——衡量团队持续交付的纪律。同时追踪团队整体连续天数和个人连续天数。
- **Step 12**：从 `.context/retros/*.json` 加载历史快照，计算关键指标的 delta 值。

---

## Step 13：保存历史快照

> **原文**：
> ```
> ### Step 13: Save Retro History
> mkdir -p .context/retros
> # Save as .context/retros/${today}-${next}.json
> ```

**中文**：用 Write 工具把本次 retro 的指标序列化为 JSON，保存到项目的 `.context/retros/` 目录。文件名格式为 `2026-03-18-1.json`（日期 + 当天序号）。

```json
{
  "date": "2026-03-08",
  "window": "7d",
  "metrics": {
    "commits": 47,
    "test_ratio": 0.41,
    "sessions": 14,
    "deep_sessions": 5,
    "ai_assisted_commits": 32
  },
  "authors": {
    "Garry Tan": { "commits": 32, "test_ratio": 0.41 }
  },
  "tweetable": "Week of Mar 1: 47 commits, 3.2k LOC, 38% tests, 12 PRs"
}
```

> **设计原理：`tweetable` 字段**
> 每次保存都生成一条"可推特摘要"。这不是多余的——它是 retro 哲学的体现：重要的事情应该能用一句话说清楚。如果你无法用 280 个字符概括这周的工程状态，你可能还没有真正理解它。

---

## 全局复盘模式（/retro global）

> **原文**：
> ```
> ## Global Retrospective Mode
> When the user runs /retro global, follow this flow instead of the repo-scoped
> Steps 1-14. This mode works from any directory — it does NOT require being
> inside a git repo.
>
> Step 2: Run discovery script
> $DISCOVER_BIN --since "<window>" --format json 2>/tmp/gstack-discover-stderr
>
> ## 🚀 Your Week: [user name] — [date range]
> ╔═══════════════════════════════════════════════════════════════
> ║  [USER NAME] — Week of [date]
> ║  [N] commits across [M] projects
> ║  +[X]k LOC added · [Y]k LOC deleted · [Z]k net
> ║  [N]-day shipping streak 🔥
> ╚═══════════════════════════════════════════════════════════════
> ```

**中文**：全局模式包含 9 个步骤：

```
/retro global 执行流程
│
├── Global Step 1: 计算时间窗口（午夜对齐）
├── Global Step 2: 运行 gstack-global-discover 脚本
│   └── 返回 JSON：{ repos: [{name, paths, remote, sessions}] }
├── Global Step 3: 对每个仓库运行 git log
│   ├── 本地仓库（local:）→ 跳过 git fetch
│   └── 远程仓库 → git fetch origin --quiet
├── Global Step 4: 计算跨项目连续发货天数
│   └── 联合所有仓库的提交日期，从今天向前数连续天数
├── Global Step 5: 上下文切换度量
│   └── 计算每天有提交的仓库数量（越少越专注）
├── Global Step 6: 按 AI 工具分析生产力模式
├── Global Step 7: 生成叙述报告
│   ├── 第一段：可截图分享的个人周卡片（Personal Card）
│   └── 第二段：完整的团队/项目深度分析
├── Global Step 8: 加载历史 (~/.gstack/retros/global-*.json)
└── Global Step 9: 保存快照到 ~/.gstack/retros/（而非 .context/retros/）
```

> **设计原理：个人卡片优先**
> 全局复盘的输出结构是"个人卡片在前，完整分析在后"。个人卡片设计为**截图友好**——左边框对齐，列宽自适应最长仓库名。这样用户可以直接截图分享到 X/Twitter，不需要任何编辑。可分享性是功能设计的一部分。

---

## 比较模式（/retro compare）

> **原文**：
> ```
> ## Compare Mode
> 1. Compute metrics for the current window (midnight-aligned)
> 2. Compute metrics for the prior same-length window (--since AND --until)
> 3. Show side-by-side comparison with deltas and arrows
> 5. Save only the current-window snapshot; do NOT persist prior-window metrics.
> ```

**中文**：比较模式计算两个相邻等长时间窗口的指标对比。关键是使用 `--since` 和 `--until` 精确划定上一个窗口的边界，避免重叠：

```
当前窗口 (7d): --since="2026-03-11T00:00:00"
上一窗口 (7d): --since="2026-03-04T00:00:00" --until="2026-03-11T00:00:00"
```

---

## 整体执行流程图

```
用户输入 /retro [args]
        │
        ▼
  Preamble 运行
  ├── 会话注册、升级检查
  ├── 遥测初始化
  ├── 首次引导（一次性）
  └── 上下文恢复
        │
        ▼
  参数解析
  ├── global → Global Flow (9 steps)
  ├── compare → Compare Flow
  └── [window] → Main Flow (Steps 1-14)
        │
        ▼ (Main Flow)
  Step 1: 12 条 git 命令并行采集数据
        │
        ▼
  Step 2: 计算摘要指标 + 贡献者排行榜
        │
        ▼
  Step 3: 小时分布直方图 (ASCII)
        │
        ▼
  Step 4: 45分钟阈值会话检测
        │
        ▼
  Step 5: 提交类型分布 (feat/fix/refactor...)
        │
        ▼
  Step 6: 文件热点分析 (Top 10)
        │
        ▼
  Step 7: PR 规模分布
        │
        ▼
  Step 8: 焦点分数 + 本周最大成果
        │
        ▼
  Step 9: 团队成员逐人分析
  ├── You: 深度分析（第一人称）
  └── 每位队友: 摘要 + 表扬 + 成长建议
        │
        ▼
  Step 10: 周趋势（≥14d 时）
        │
        ▼
  Step 11: 连续发货天数（团队 + 个人）
        │
        ▼
  Step 12: 加载历史，计算 delta
        │
        ▼
  Step 13: 保存 JSON 快照到 .context/retros/
        │
        ▼
  Step 14: 生成完整叙述报告（输出到对话）
        │
        ▼
  Telemetry: 记录耗时和结果
```

---

## 设计核心思路汇总

| 设计决策 | 具体实现 | 背后原因 |
|----------|----------|----------|
| 使用 `origin/<default>` 而非本地分支 | `git log origin/main` | 本地可能 stale，retro 要看团队真实合并情况 |
| 午夜对齐时间窗口 | `--since="2026-03-11T00:00:00"` | 让"本周"定义稳定，结果可重现 |
| 12 条 git 命令并行执行 | 显式标注"independent" | 减少总耗时，各命令互不依赖 |
| 45 分钟会话阈值 | 会话检测逻辑 | 平衡过度切割和过度合并的边界 |
| "You First" 叙事 | `git config user.name` 识别当前用户 | 主受众是运行命令的人，个人数据最重要 |
| 表扬锚定在具体 commit | "Not 'great work'" 规则 | 空泛表扬是噪音，具体才有价值 |
| `tweetable` 字段 | 每次保存都生成一句话摘要 | 强迫提炼，让复杂指标变成可传播的信号 |
| 个人卡片截图友好 | 左边框对齐，列宽自适应 | 可分享性是功能的一部分 |
| 历史快照持久化 | `.context/retros/*.json` | 支持趋势分析，让进步/退步可见 |
| 全局模式不依赖 git repo | `global` 子命令单独处理 | 开发者往往维护多个项目，单仓库视角不完整 |
| 遥测完全本地写入 | `~/.gstack/analytics/skill-usage.jsonl` | 不发送代码和文件路径，只发统计数据（且默认 off） |
