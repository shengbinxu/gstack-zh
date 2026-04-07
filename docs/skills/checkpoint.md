# `/checkpoint` 技能逐段中英对照注解

> 对应源文件：[`checkpoint/SKILL.md`](https://github.com/garrytan/gstack/blob/main/checkpoint/SKILL.md)（约 814 行，含 Preamble 展开）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: checkpoint
preamble-tier: 2
version: 1.0.0
description: |
  Save and resume working state checkpoints. Captures git state, decisions made,
  and remaining work so you can pick up exactly where you left off — even across
  Conductor workspace handoffs between branches.
  Use when asked to "checkpoint", "save progress", "where was I", "resume",
  "what was I working on", or "pick up where I left off".
  Proactively suggest when a session is ending, the user is switching context,
  or before a long break. (gstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---
```

**中文翻译**：

- **name**: 技能名称，用户输入 `/checkpoint` 触发。
- **preamble-tier: 2**: 与 `/retro` 相同的 Preamble 级别——会话管理、遥测、语音风格、上下文恢复。
- **description**: 保存和恢复工作状态检查点。捕获 git 状态、已做决策、剩余工作，让你能**精确**地从上次停下的地方继续——即使跨越 Conductor 工作区的分支切换。
- **allowed-tools**: 有 Grep——因为 resume 流程需要在 checkpoint 文件中搜索特定内容（如标题片段）。没有 Edit——checkpoint 是**追加写入**（append-only），每次保存创建新文件。

> **设计原理：为什么需要 checkpoint？**
> Claude 的上下文窗口是有限的。一个复杂的 bug 修复可能跨越多个 Claude 会话（重开对话窗口、上下文被压缩、切换到别的 branch 做别的事）。没有 checkpoint，每次重新开始都要花几分钟重建上下文——"我当时在做什么？做到哪了？为什么这么选？"。checkpoint 把这个开销从几分钟降到几秒钟。

---

## {{PREAMBLE}} 展开区

checkpoint 的 Preamble 与 retro 完全相同（tier 2），包含：会话跟踪、升级检查、配置读取、渐进式首次引导（Boil the Lake 哲学介绍、遥测偏好、主动模式偏好、CLAUDE.md 路由规则注入）、上下文恢复。

其中 **CLAUDE.md 路由规则注入**对 checkpoint 特别重要，因为它会在路由规则中包含：

```markdown
- Save progress, checkpoint, resume → invoke checkpoint
```

这确保用户说"帮我保存进度"时，Claude 会自动调用 `/checkpoint` 而不是临时生成一个文字摘要。

> **设计原理：路由规则的意义**
> 如果没有路由规则，Claude 可能在用户说"保存一下进度"时，随手写一段对话摘要放在对话框里——这种摘要在对话结束后就消失了。路由规则确保调用专门的技能，把状态写入持久化文件。

---

## 技能核心声明

> **原文**：
> ```
> # /checkpoint — Save and Resume Working State
>
> You are a Staff Engineer who keeps meticulous session notes. Your job is to
> capture the full working context — what's being done, what decisions were made,
> what's left — so that any future session (even on a different branch or workspace)
> can resume without losing a beat.
>
> HARD GATE: Do NOT implement code changes. This skill captures and restores
> context only.
> ```

**中文**："你是一个保持严谨会话笔记的高级工程师。你的工作是捕获完整的工作上下文——正在做什么、做了哪些决策、还剩什么——让任何未来的会话（即使在不同分支或工作区上）都能无缝继续。"

**硬性限制：不实现任何代码变更。这个技能只负责捕获和恢复上下文。**

> **设计原理：HARD GATE 的必要性**
> 如果 checkpoint 能改代码，它就变成了一个"帮我继续写"的命令，而不是一个"帮我记录在哪"的命令。HARD GATE 使职责单一，用户知道运行 `/checkpoint` 绝对不会修改任何文件，只会创建一个新的检查点文件。这种可预测性是信任的基础。

---

## 命令检测

> **原文**：
> ```
> ## Detect command
> - /checkpoint or /checkpoint save → Save
> - /checkpoint resume              → Resume
> - /checkpoint list                → List
>
> If the user provides a title after the command (e.g., /checkpoint auth refactor),
> use it as the checkpoint title. Otherwise, infer a title from the current work.
> ```

**中文**：checkpoint 是一个**多命令技能**，根据子命令路由到三个不同的工作流：

```
/checkpoint [save]     → Save Flow（默认：保存当前状态）
/checkpoint resume     → Resume Flow（恢复最近或指定的检查点）
/checkpoint list       → List Flow（展示该项目所有检查点）
/checkpoint list --all → List Flow（所有分支的检查点）
```

用户可以在命令后附加标题（如 `/checkpoint auth-refactor-phase2`），否则 AI 自动从当前工作推断标题（3-6 个词的简洁短语）。

---

## Save Flow（保存流程）

### Step 1：采集工作状态

> **原文**：
> ```
> echo "=== BRANCH ==="
> git rev-parse --abbrev-ref HEAD 2>/dev/null
> echo "=== STATUS ==="
> git status --short 2>/dev/null
> echo "=== DIFF STAT ==="
> git diff --stat 2>/dev/null
> echo "=== STAGED DIFF STAT ==="
> git diff --cached --stat 2>/dev/null
> echo "=== RECENT LOG ==="
> git log --oneline -10 2>/dev/null
> ```

**中文**：采集 5 个维度的 git 状态：

| 命令 | 采集内容 | 用途 |
|------|----------|------|
| `rev-parse --abbrev-ref HEAD` | 当前分支名 | checkpoint 文件的 frontmatter |
| `git status --short` | 修改/暂存文件列表 | `files_modified` 字段 |
| `git diff --stat` | 未暂存变更的文件统计 | 了解工作量规模 |
| `git diff --cached --stat` | 已暂存变更的文件统计 | 了解准备提交的内容 |
| `git log --oneline -10` | 最近 10 条提交 | 恢复时理解历史背景 |

### Step 2：总结上下文

> **原文**：
> ```
> Using the gathered state plus your conversation history, produce a summary covering:
> 1. What's being worked on — the high-level goal or feature
> 2. Decisions made — architectural choices, trade-offs, approaches chosen and why
> 3. Remaining work — concrete next steps, in priority order
> 4. Notes — anything a future session needs to know (gotchas, blocked items,
>    open questions, things that were tried and didn't work)
> ```

**中文**：这是 checkpoint 最核心的一步。AI 结合 git 状态和**对话历史**（不只是代码）生成摘要，覆盖：

1. **正在做什么**：高层次目标或功能描述
2. **已做决策**：架构选择、权衡点、选择某种方案的原因
3. **剩余工作**：具体下一步（按优先级排序）
4. **注意事项**：坑、阻塞项、开放问题、已尝试过但不可行的方案

> **设计原理：决策是最珍贵的上下文**
> 代码可以用 `git status` 恢复，但"为什么这么设计"是最容易丢失的信息。一个月后，或者另一个 Claude 会话里，代码看起来可能莫名其妙——如果有 checkpoint 记录了"我们试过 X 方案，但因为 Y 原因放弃了，最终选了 Z"，就能避免重复踩同一个坑。

### Step 3：计算会话时长

> **原文**：
> ```
> if [ -n "$_TEL_START" ]; then
>   START_EPOCH="$_TEL_START"
> elif [ -n "$PPID" ]; then
>   START_EPOCH=$(ps -o lstart= -p $PPID 2>/dev/null | ...)
> fi
> DURATION=$((NOW - START_EPOCH))
> ```

**中文**：尝试通过两种方式确定会话时长：
1. `$_TEL_START`：Preamble 中记录的技能启动时间戳（最准确）
2. `$PPID` 的进程启动时间：作为回退方案

如果无法确定，在 checkpoint 文件中省略 `session_duration_s` 字段（而不是写 0 或 unknown）。

### Step 4：写入 Checkpoint 文件

> **原文**：
> ```
> CHECKPOINT_DIR="$HOME/.gstack/projects/$SLUG/checkpoints"
> TIMESTAMP=$(date +%Y%m%d-%H%M%S)
> # Write to: {CHECKPOINT_DIR}/{TIMESTAMP}-{title-slug}.md
>
> ---
> status: in-progress
> branch: {current branch name}
> timestamp: {ISO-8601 timestamp}
> session_duration_s: {computed duration}
> files_modified:
>   - path/to/file1
> ---
>
> ## Working on: {title}
> ### Summary
> ### Decisions Made
> ### Remaining Work
> ### Notes
> ```

**中文**：文件路径结构：

```
~/.gstack/projects/
└── {project-slug}/
    └── checkpoints/
        ├── 20260331-143000-auth-refactor.md
        ├── 20260330-092000-api-pagination.md
        └── 20260328-180000-db-migration-setup.md
```

文件名 = 时间戳（精确到秒）+ 标题 kebab-case。这确保文件按时间自然排序，且文件名本身就是可读的摘要。

确认输出格式：

```
CHECKPOINT SAVED
════════════════════════════════════════
Title:    auth-refactor-phase2
Branch:   feat/auth
File:     ~/.gstack/projects/myapp/checkpoints/20260331-143000-auth-refactor-phase2.md
Modified: 4 files
Duration: 47 minutes
════════════════════════════════════════
```

> **设计原理：保存到 `~/.gstack/` 而非项目目录**
> checkpoint 文件存储在用户主目录（`~/.gstack/`），不在项目目录（如 `.context/`）。这有两个好处：
> 1. **安全**：不会意外 commit 进 git（个人笔记不应该进版本控制）
> 2. **跨工作区**：即使项目被删除/重建，checkpoint 依然存在

---

## Resume Flow（恢复流程）

### Step 1：查找检查点

> **原文**：
> ```
> CHECKPOINT_DIR="$HOME/.gstack/projects/$SLUG/checkpoints"
> find "$CHECKPOINT_DIR" -maxdepth 1 -name "*.md" -type f | xargs ls -1t | head -20
>
> List checkpoints from all branches (checkpoint files contain the branch name
> in their frontmatter, so all files in the directory are candidates). This
> enables Conductor workspace handoff.
> ```

**中文**：列出**所有分支**的 checkpoint（而不是只列出当前分支的）。这是 Conductor 工作区切换的核心——你可能在 `feat/auth` 上保存了一个 checkpoint，然后切换到 `main` 修复了一个紧急 bug，再切回 `feat/auth` 时，通过 resume 能找到之前的上下文。

> **设计原理：跨分支 checkpoint 的价值**
> 只列出当前分支的 checkpoint 是一个直觉性但错误的设计。开发者频繁切换分支。checkpoint 存储时记录了 `branch` 字段，resume 时可以感知"这个 checkpoint 是在另一个分支保存的"，并给出提醒，而不是简单地隐藏它。

### Step 2：加载并展示

> **原文**：
> ```
> RESUMING CHECKPOINT
> ════════════════════════════════════════
> Title:       auth-refactor-phase2
> Branch:      feat/auth
> Saved:       2026-03-31 14:30 (2 hours ago)
> Duration:    Last session was 47 minutes
> Status:      in-progress
> ════════════════════════════════════════
>
> If the current branch differs from the checkpoint's branch, note this:
> "This checkpoint was saved on branch `feat/auth`. You are currently on
> `main`. You may want to switch branches before continuing."
> ```

**中文**：加载最近（或用户指定）的 checkpoint，展示结构化摘要。如果当前分支和 checkpoint 的分支不同，给出明确提示——不阻止继续，只是告知，保留用户决策权（User Sovereignty）。

### Step 3：提供后续选项

> **原文**：
> ```
> After presenting the checkpoint, ask via AskUserQuestion:
> - A) Continue working on the remaining items
> - B) Show the full checkpoint file
> - C) Just needed the context, thanks
>
> If A, summarize the first remaining work item and suggest starting there.
> ```

**中文**：resume 不会自动开始工作——它先展示上下文，再问"你想怎么继续"。三个选项对应三种典型场景：
- A：真正要继续工作
- B：想回顾完整的决策历史
- C：只是想想起"我当时做到哪了"，接下来自己决定

---

## List Flow（列表流程）

> **原文**：
> ```
> Default behavior: Show checkpoints for the current branch only.
> If the user passes --all, show checkpoints from all branches.
>
> CHECKPOINTS (all branches)
> ════════════════════════════════════════
> #  Date        Title                    Branch              Status
> ─  ──────────  ───────────────────────  ──────────────────  ───────────
> 1  2026-03-31  auth-refactor            feat/auth           in-progress
> 2  2026-03-30  api-pagination           main                completed
> ════════════════════════════════════════
> ```

**中文**：
- 默认只显示当前分支的 checkpoint
- `--all` 标志显示所有分支，增加 Branch 列
- 从 checkpoint 文件的 frontmatter 解析 `status`、`branch`、`timestamp`；从文件名解析标题

---

## 重要规则

> **原文**：
> ```
> ## Important Rules
> - Never modify code. This skill only reads state and writes checkpoint files.
> - Always include the branch name in checkpoint files.
> - Checkpoint files are append-only. Never overwrite or delete existing checkpoint files.
>   Each save creates a new file.
> - Infer, don't interrogate. Use git state and conversation context to fill in
>   the checkpoint. Only use AskUserQuestion if the title genuinely cannot be inferred.
> ```

**中文**：四条核心规则：

1. **永不修改代码**：只读 git 状态，只写 checkpoint 文件。
2. **始终记录分支名**：这是跨分支 resume 的基础。
3. **追加写入，不覆盖**：每次 save 都创建新文件。这意味着你有完整的检查点历史，可以回到任意一个历史时间点。
4. **推断，不询问**：尽量从 git 状态和对话上下文自动填写内容，只在标题真的无法推断时才用 AskUserQuestion 询问。

> **设计原理：追加写入的意义**
> 如果每次 save 都覆盖同一个文件，你只有"最新状态"，但没有"历史轨迹"。追加写入让每次保存都成为一个快照，你可以看到"上午 10 点做了哪些决策"和"下午 4 点做了哪些决策"的演变。这对于复杂的多阶段任务（如一个持续几天的重构）特别有价值。

---

## 与其他技能的关系

```
checkpoint 在 gstack 生态中的位置
│
├── 被 Context Recovery 使用
│   └── 所有 Preamble 都会检查 LATEST_CHECKPOINT，如果存在就读取并恢复上下文
│
├── 被 /retro 引用
│   └── retro 的 Context Recovery 部分会读取最新 checkpoint
│
├── 配合 /ship 使用
│   └── 在 /ship 前运行 /checkpoint save，确保如果 ship 失败能回到原点
│
└── 配合 Conductor 使用
    └── 跨分支 workspace 切换时，通过 checkpoint 传递上下文
```

---

## 整体执行流程图

```
用户输入 /checkpoint [save|resume|list] [title] [--all]
        │
        ▼
  Preamble 运行
  ├── 会话注册、升级检查
  ├── 遥测初始化
  ├── 首次引导（一次性）
  └── 上下文恢复（读取 LATEST_CHECKPOINT）
        │
        ▼
  命令检测
  ├── save (默认) → Save Flow
  ├── resume → Resume Flow
  └── list → List Flow
        │
        ├─── Save Flow ────────────────────────────────────────┐
        │    Step 1: git status/diff/log 采集当前状态           │
        │    Step 2: 结合对话历史生成 4 段摘要                   │
        │            ├── 正在做什么                             │
        │            ├── 已做决策（最重要）                      │
        │            ├── 剩余工作（按优先级）                    │
        │            └── 注意事项（坑/阻塞/已试方案）            │
        │    Step 3: 计算会话时长                               │
        │    Step 4: 写入 .md 文件                             │
        │            ~/.gstack/projects/$SLUG/checkpoints/    │
        │            {TIMESTAMP}-{title-slug}.md              │
        │    确认输出 CHECKPOINT SAVED 摘要                     │
        │                                                      │
        ├─── Resume Flow ──────────────────────────────────────┤
        │    Step 1: 列出所有分支的 checkpoint (最新20个)        │
        │    Step 2: 读取最近/指定的 checkpoint                 │
        │            如果跨分支：显示分支差异提示                 │
        │    Step 3: AskUserQuestion                           │
        │            A) 继续工作 → 从第一个剩余任务开始           │
        │            B) 显示完整文件                            │
        │            C) 只需上下文，谢谢                         │
        │                                                      │
        └─── List Flow ────────────────────────────────────────┘
             Step 1: 找出所有 checkpoint 文件
             Step 2: 读取每个文件的 frontmatter
                     默认：只显示当前分支
                     --all：显示所有分支（含 Branch 列）
             展示表格
        │
        ▼
  Telemetry: 记录耗时和结果
```

---

## 设计核心思路汇总

| 设计决策 | 具体实现 | 背后原因 |
|----------|----------|----------|
| HARD GATE：不修改代码 | 显式禁止 Edit 工具 | 职责单一，用户对 /checkpoint 的行为有完整预期 |
| 追加写入，不覆盖 | 每次保存创建新文件 | 保留完整历史轨迹，可回到任意历史快照 |
| 存储在 `~/.gstack/` 而非项目目录 | `~/.gstack/projects/$SLUG/checkpoints/` | 不污染 git，跨工作区可访问 |
| 跨分支列出所有 checkpoint | resume 默认读全局，不过滤分支 | 开发者频繁切换分支，checkpoint 要跟着人走，不跟着分支走 |
| 推断标题，不询问 | 从 git 状态和对话历史自动生成 | 减少摩擦，checkpoint 越容易保存，用户越会频繁使用 |
| 决策记录是核心字段 | "Decisions Made" 独立成节 | 代码可以从 git 恢复，决策原因不能——这是最容易丢失的信息 |
| 分支差异提示但不阻止 | 只提示，用户自己决定 | User Sovereignty：用户有上下文，AI 没有 |
| session_duration_s 字段 | 可选，无法计算时省略 | 让用户了解上次会话投入了多少时间 |
| Context Recovery 复用 | Preamble 中的 LATEST_CHECKPOINT | 即使不主动运行 /checkpoint resume，每次新会话也能自动感知最近状态 |
