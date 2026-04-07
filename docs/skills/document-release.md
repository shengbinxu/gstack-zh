# `/document-release` 技能逐段中英对照注解

> 对应源文件：[`document-release/SKILL.md`](https://github.com/garrytan/gstack/blob/main/document-release/SKILL.md)（925 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## 一、技能定位总览

`/document-release` 是 gstack 工作流的**最后一公里**。代码已经写好、PR 已经创建（通过 `/ship`）——现在确保文档跟上。

```
gstack 发布工作流（时间轴）：

  ┌─────────────┐    ┌─────────────┐    ┌──────────────────────┐
  │  /plan-eng  │ →  │    /ship    │ →  │  /document-release   │
  │   review    │    │             │    │                      │
  │  方案评审    │    │  创建PR     │    │  PR合并前更新文档     │
  └─────────────┘    └─────────────┘    └──────────────────────┘
        │                  │                      │
     锁定方案           提交代码               同步文档
     架构设计           创建PR                 声音打磨
                         版本管理               一致性检查
```

**核心价值主张**：代码合并了，但 README 还在描述旧功能；ARCHITECTURE.md 的组件图过时了；CHANGELOG 写得像 git commit message。这种技术债每次发布都在积累。`/document-release` 在 PR 合并前把这些都清理掉。

**与 `/ship` 的分工**：
- `/ship`：检测分支 → 跑测试 → 审查 diff → 更新 CHANGELOG（写入新版本条目）→ 提交 → 推送 → 创建 PR
- `/document-release`：在 PR 合并前，更新 README/ARCHITECTURE/CONTRIBUTING/CLAUDE.md → 润色 CHANGELOG 声音 → 清理 TODOS → 处理 VERSION

---

## 二、Frontmatter（元数据区）

> **原文**：
> ```yaml
> ---
> name: document-release
> preamble-tier: 2
> version: 1.0.0
> description: |
>   Post-ship documentation update. Reads all project docs, cross-references the
>   diff, updates README/ARCHITECTURE/CONTRIBUTING/CLAUDE.md to match what shipped,
>   polishes CHANGELOG voice, cleans up TODOS, and optionally bumps VERSION. Use when
>   asked to "update the docs", "sync documentation", or "post-ship docs".
>   Proactively suggest after a PR is merged or code is shipped. (gstack)
> allowed-tools:
>   - Bash
>   - Read
>   - Write
>   - Edit
>   - Grep
>   - Glob
>   - AskUserQuestion
> ---
> ```

**中文翻译**：

- **preamble-tier: 2**：轻量级初始化。不需要 Search Before Building（文档更新不需要研究外部知识），不需要 repo 模式检测（单分支操作）。
- **allowed-tools 分析**：

| 工具 | 用途 |
|------|------|
| `Bash` | git diff、git log、gh pr 命令 |
| `Read` | 读取所有 .md 文件 |
| `Write` | 创建新文件（如 ARCHITECTURE.md 不存在时） |
| `Edit` | **CHANGELOG.md 只允许用 Edit**（不允许 Write，防止覆盖） |
| `Grep` | 在文档中搜索关键词 |
| `Glob` | 发现项目中所有 .md 文件 |
| `AskUserQuestion` | 风险决策（narrative 变更、VERSION 管理） |

**关键约束**：`Edit`（精确字符串替换）用于 CHANGELOG.md，不用 `Write`（全文覆盖）。这是防止意外覆盖 CHANGELOG 历史条目的技术手段。

---

## 三、AUTO vs ASK 分类机制

这是 `/document-release` 最核心的设计决策。

> **原文**：
> ```
> You are mostly automated. Make obvious factual updates directly. Stop and ask only for risky or
> subjective decisions.
>
> Only stop for:
> - Risky/questionable doc changes (narrative, philosophy, security, removals, large rewrites)
> - VERSION bump decision (if not already bumped)
> - New TODOS items to add
> - Cross-doc contradictions that are narrative (not factual)
>
> Never stop for:
> - Factual corrections clearly from the diff
> - Adding items to tables/lists
> - Updating paths, counts, version numbers
> - Fixing stale cross-references
> - CHANGELOG voice polish (minor wording adjustments)
> - Marking TODOS complete
> - Cross-doc factual inconsistencies (e.g., version number mismatch)
> ```

**中文**：

AUTO-UPDATE（自动执行，不问用户）：

```
┌──────────────────────────────────────────────────────────────┐
│                    AUTO-UPDATE 触发条件                       │
├──────────────────────────────────────────────────────────────┤
│  • 表格中添加新条目（如 README 的技能列表）                     │
│  • 更新文件路径（A.ts 改名为 B.ts）                            │
│  • 修正数量（"9 个技能" → "10 个技能"）                        │
│  • 修复过期交叉引用（文件已移动，链接失效）                      │
│  • CHANGELOG 轻微措辞调整（"重构了" → "你现在可以..."）         │
│  • 标记 TODOS 条目为已完成（diff 中有明确证据）                  │
│  • 修正不同文档间的事实性不一致（版本号不匹配等）                │
└──────────────────────────────────────────────────────────────┘
```

ASK USER（必须通过 AskUserQuestion 确认）：

```
┌──────────────────────────────────────────────────────────────┐
│                    ASK USER 触发条件                          │
├──────────────────────────────────────────────────────────────┤
│  • Narrative 变更（改变项目定位描述、哲学陈述）                  │
│  • 删除整个文档章节                                             │
│  • 安全模型描述变更                                             │
│  • 大规模重写（某章节超过约10行）                               │
│  • VERSION 管理（无论是否已有版本号）                           │
│  • 新增 TODOS 条目                                              │
│  • 叙述性矛盾（非事实性，涉及语气或立场）                        │
└──────────────────────────────────────────────────────────────┘
```

**设计原理**：文档更新的自动化程度要高——手工处理每个 diff 相关的文档变更是不现实的。但叙述性内容（"这个项目是什么"、"为什么这样设计"）是人的判断领域，AI 不能擅自改。这个 AUTO/ASK 分类是实用性和安全性的平衡。

---

## 四、Step 0：检测 Git 平台和基础分支

> **原文**：
> ```bash
> git remote get-url origin 2>/dev/null
> ```
>
> - If the URL contains "github.com" → platform is **GitHub**
> - If the URL contains "gitlab" → platform is **GitLab**
> - Otherwise, check CLI availability:
>   - `gh auth status 2>/dev/null` succeeds → **GitHub**
>   - `glab auth status 2>/dev/null` succeeds → **GitLab**
>   - Neither → **unknown** (use git-native commands only)

**中文**：在做任何文档操作之前，先检测 git 平台。原因：PR body 更新（Step 9）在不同平台用不同 CLI：

| 平台 | PR/MR 命令 | 连接 |
|------|-----------|------|
| GitHub | `gh pr view`、`gh pr edit` | `github.com` URL 或 `gh` CLI 可用 |
| GitLab | `glab mr view`、`glab mr update` | `gitlab` URL 或 `glab` CLI 可用 |
| 未知 | 仅 git 原生命令 | 无法更新 PR body |

**基础分支检测优先级**：

```
GitHub：
  1. gh pr view --json baseRefName      (当前PR的目标分支)
  2. gh repo view --json defaultBranchRef  (仓库默认分支)

GitLab：
  1. glab mr view -F json → target_branch
  2. glab repo view -F json → default_branch

Git 原生 fallback：
  1. git symbolic-ref refs/remotes/origin/HEAD
  2. origin/main 存在？→ main
  3. origin/master 存在？→ master
  4. 全失败 → main
```

**为什么需要精确的基础分支？** `git diff <base>...HEAD` 的 `<base>` 必须正确。如果用 `main` 但实际目标是 `develop`，diff 分析会包含太多无关内容，导致文档更新范围不准确。

---

## 五、Step 1：预检与 Diff 分析

> **原文**：
> ```
> 1. Check the current branch. If on the base branch, abort: "You're on the base branch.
>    Run from a feature branch."
>
> 2. Gather context about what changed:
>    git diff <base>...HEAD --stat
>    git log <base>..HEAD --oneline
>    git diff <base>...HEAD --name-only
>
> 3. Discover all documentation files in the repo:
>    find . -maxdepth 2 -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*" \
>      -not -path "./.gstack/*" -not -path "./.context/*" | sort
>
> 4. Classify the changes into categories:
>    - New features — new files, new commands, new skills, new capabilities
>    - Changed behavior — modified services, updated APIs, config changes
>    - Removed functionality — deleted files, removed commands
>    - Infrastructure — build system, test infrastructure, CI
>
> 5. Output a brief summary: "Analyzing N files changed across M commits..."
> ```

**中文**：

Step 1 是"情报收集"阶段。三个 git 命令提供不同粒度的信息：

```
git diff <base>...HEAD --stat
→ 哪些文件改了，改了多少行
→ 用于判断变更规模和范围

git log <base>..HEAD --oneline
→ 提交历史（每条 commit message）
→ 用于理解变更的意图和顺序

git diff <base>...HEAD --name-only
→ 所有改动文件的路径列表
→ 用于 find . 的 md 文件扫描结果比对
```

**注意 `...` vs `..` 的区别**：
- `git diff A...B` = A 和 B 的共同祖先到 B 的差异（feature 分支相对 base 的净变化）
- `git diff A..B` = A 到 B 的直接差异（包含 base 分支上的变化）

`git diff <base>...HEAD --stat` 用三点，确保只看 feature 分支的贡献。

**变更分类目的**：不同类型的变更对文档的影响不同：
- **新功能** → README 需要新增功能介绍
- **行为变更** → ARCHITECTURE.md 可能需要更新组件交互描述
- **删除功能** → 所有文档需要清理对应章节的引用
- **基础设施** → CONTRIBUTING.md 的开发环境配置可能过期

---

## 六、Step 2：逐文件文档审计

> **原文**：
> ```
> README.md:
> - Does it describe all features and capabilities visible in the diff?
> - Are install/setup instructions consistent with the changes?
> - Are examples, demos, and usage descriptions still valid?
>
> ARCHITECTURE.md:
> - Do ASCII diagrams and component descriptions match the current code?
> - Are design decisions and "why" explanations still accurate?
> - Be conservative — only update things clearly contradicted by the diff.
>
> CONTRIBUTING.md — New contributor smoke test:
> - Walk through the setup instructions as if you are a brand new contributor.
> - Are the listed commands accurate? Would each step succeed?
>
> CLAUDE.md / project instructions:
> - Does the project structure section match the actual file tree?
> - Are listed commands and scripts accurate?
> - Do build/test instructions match what's in package.json (or equivalent)?
> ```

**中文**：

每个文档文件的审计视角不同：

```
┌─────────────────┬───────────────────────────────┬─────────────────────────────┐
│ 文件             │ 审计视角                       │ 保守程度                     │
├─────────────────┼───────────────────────────────┼─────────────────────────────┤
│ README.md       │ 用户视角：功能、用法、示例       │ 激进（功能变了就改）           │
│ ARCHITECTURE.md │ 工程师视角：组件、数据流         │ 保守（只改明确被contradicted的）│
│ CONTRIBUTING.md │ 新贡献者视角：setup、workflow   │ 中等（命令准确性最重要）        │
│ CLAUDE.md       │ AI 协作视角：项目结构、命令      │ 激进（AI 指令要准确）           │
│ 其他 .md        │ 判断用途和受众再决定             │ 按具体情况                     │
└─────────────────┴───────────────────────────────┴─────────────────────────────┘
```

**ARCHITECTURE.md 保守原则的理由**：架构文档里有很多"为什么这样设计"的解释——这些是人的判断，AI 不应该擅自修改。只有当 diff 明确显示某个组件被删除或重命名，才更新对应描述。

**CONTRIBUTING.md "新贡献者烟雾测试"**：把自己想象成完全不了解项目的新人，逐步走一遍文档里的 setup 步骤。哪个命令现在会失败？哪个工具描述已经过时？这是最实用的文档健康检查视角。

---

## 七、Step 3：应用自动更新

> **原文**：
> ```
> Make all clear, factual updates directly using the Edit tool.
>
> For each file modified, output a one-line summary describing what specifically changed —
> not just "Updated README.md" but "README.md: added /new-skill to skills table,
> updated skill count from 9 to 10."
>
> Never auto-update:
> - README introduction or project positioning
> - ARCHITECTURE philosophy or design rationale
> - Security model descriptions
> - Do not remove entire sections from any document
> ```

**中文**：

自动更新的输出规范很重要：不是"Updated README.md"，而是"README.md: added /document-release to skills table, updated skill count from 9 to 10"。这让 git commit message 和 PR body 有实质内容。

**永远不自动更新的内容**：

```
README introduction（项目介绍第一段）
→ 改变项目的核心定位，需要人来决定

ARCHITECTURE philosophy
→ "我们为什么选择这个架构"是判断性陈述

Security model descriptions
→ 错误更新安全描述可能引发误导或安全漏洞

整个章节的删除
→ 删除是破坏性操作，必须人工确认
```

---

## 八、Step 4：风险变更确认

> **原文**：
> ```
> For each risky or questionable update identified in Step 2, use AskUserQuestion with:
> - Context: project name, branch, which doc file, what we're reviewing
> - The specific documentation decision
> - RECOMMENDATION: Choose [X] because [one-line reason]
> - Options including C) Skip — leave as-is
> ```

**中文**：风险变更走 AskUserQuestion 流程。问法遵循标准 AskUserQuestion 格式：

1. **Re-ground**：项目名 + 分支名 + 当前任务（来自 preamble 的 `_BRANCH`，不是对话历史）
2. **Simplify**：用普通话解释是什么文档问题，不用技术术语
3. **RECOMMENDATION**：给出推荐选项 + 简短理由
4. **Options**：A/B/C 选项，C 通常是"Skip — leave as-is"

**示例场景**：ARCHITECTURE.md 有一节描述某个服务，但 diff 显示该服务已被完全重构。

```
Re-ground: 项目 my-project，分支 feature/refactor-auth-service，正在更新 ARCHITECTURE.md。

Simplify: 架构文档有一节（约 25 行）描述 AuthService 的设计，但这次重构
基本重写了它。如果保持原样，文档会误导新人对代码的理解。

RECOMMENDATION: 选 A，因为架构文档的核心价值是准确反映当前系统。

A) 重写这一节（我来描述新设计）
   Completeness: 9/10
B) 删除这一节（等后面有空再补）
   Completeness: 4/10
C) 保持原样，暂时不改
   Completeness: 2/10
```

---

## 九、Step 5：CHANGELOG 声音打磨

这是整个技能中规则最多、风险最高的步骤。有真实事故记录在案。

> **原文**：
> ```
> CRITICAL — NEVER CLOBBER CHANGELOG ENTRIES.
>
> This step polishes voice. It does NOT rewrite, replace, or regenerate CHANGELOG content.
>
> A real incident occurred where an agent replaced existing CHANGELOG entries when it should have
> preserved them. This skill must NEVER do that.
>
> Rules:
> 1. Read the entire CHANGELOG.md first. Understand what is already there.
> 2. Only modify wording within existing entries. Never delete, reorder, or replace entries.
> 3. Never regenerate a CHANGELOG entry from scratch.
> 4. If an entry looks wrong or incomplete, use AskUserQuestion — do NOT silently fix it.
> 5. Use Edit tool with exact old_string matches — never use Write to overwrite CHANGELOG.md.
> ```

**中文**：

"真实事故"这段话很少出现在 SKILL.md 里。能被写进文档，说明它确实发生了，而且影响足够严重到要特别提醒。**AI 用 Write 覆盖了整个 CHANGELOG.md**，把历史条目全部替换成重新生成的内容——这是不可逆的数据损失。

**为什么用 Edit 不用 Write？**

```
Edit 工具（安全）：
  • 需要提供 old_string（精确匹配）
  • 只替换指定的字符串片段
  • 如果 old_string 不存在，操作失败（有保护）
  • 无法意外覆盖其他内容

Write 工具（危险）：
  • 传入整个文件内容
  • 直接覆盖文件
  • 一旦内容构造有误，整个文件被破坏
  • CHANGELOG 的历史条目可能消失
```

**声音打磨的规范**：

> **原文**：
> ```
> - Sell test: Would a user reading each bullet think "oh nice, I want to try that"?
> - Lead with what the user can now DO — not implementation details.
> - "You can now..." not "Refactored the..."
> - Flag and rewrite any entry that reads like a commit message.
> - Internal/contributor changes belong in a separate "### For contributors" subsection.
> ```

**中文**：CHANGELOG 的核心原则是"用户第一"。用户不关心内部重构，只关心功能变化对他们意味着什么。

**好的 CHANGELOG 条目 vs 坏的**：

```
坏（commit message 风格）：
- Refactored auth middleware to use JWT instead of sessions

坏（技术实现导向）：
- Replaced session-based authentication with JWT token validation

好（用户导向）：
- You can now stay logged in across browser sessions — auth tokens last 7 days

坏（被动语态，无主语）：
- Token expiry handling was improved

好（"You" 视角）：
- You'll get a clear "session expired" message instead of a cryptic 500 error
```

**"For contributors" 子节**：

```markdown
### v1.2.3
- You can now search learnings by keyword: `/learn search auth`
- Prune stale learnings with `/learn prune` — it auto-detects deleted files

### For contributors
- Added `gstack-learnings-search` binary with `--query` flag
- Migrated learnings storage from SQLite to JSONL for portability
```

---

## 十、Step 6：跨文档一致性与可发现性检查

> **原文**：
> ```
> After auditing each file individually, do a cross-doc consistency pass:
>
> 1. Does the README's feature list match what CLAUDE.md describes?
> 2. Does ARCHITECTURE's component list match CONTRIBUTING's project structure?
> 3. Does CHANGELOG's latest version match the VERSION file?
> 4. Discoverability: Is every documentation file reachable from README.md or CLAUDE.md?
>    If ARCHITECTURE.md exists but neither README nor CLAUDE.md links to it, flag it.
> 5. Flag any contradictions. Auto-fix clear factual inconsistencies.
>    Use AskUserQuestion for narrative contradictions.
> ```

**中文**：

单文件审计容易发现文件内部的过时内容，但文档间的不一致更隐蔽。常见的跨文档不一致场景：

| 不一致类型 | 例子 | 处理方式 |
|-----------|------|---------|
| 版本号不匹配 | CHANGELOG 说 v1.3.0，VERSION 文件还是 v1.2.9 | AUTO（明显的事实错误） |
| 功能列表不同步 | README 有 10 个功能，CLAUDE.md 只列了 8 个 | AUTO（添加缺失的2个） |
| 组件描述矛盾 | README 说"用 Redis 做缓存"，ARCHITECTURE 说"用内存缓存" | ASK（可能是架构演变） |
| 文档可发现性 | ARCHITECTURE.md 存在但 README 没有链接到它 | AUTO（添加链接） |
| 安装命令不同 | README 说 `npm install`，CONTRIBUTING 说 `bun install` | ASK（语言变化或错误？） |

**可发现性原则**：每个文档文件必须从 README.md 或 CLAUDE.md 之一可达。孤立的文档文件（无入口链接）对新人来说等于不存在。

---

## 十一、Step 7：TODOS.md 清理

> **原文**：
> ```
> If TODOS.md does not exist, skip this step.
>
> 1. Completed items not yet marked: Cross-reference the diff against open TODO items.
>    If a TODO is clearly completed by the changes in this branch, move it to the
>    Completed section with **Completed:** vX.Y.Z.W (YYYY-MM-DD). Be conservative.
>
> 2. Items needing description updates: If a TODO references files or components
>    significantly changed, use AskUserQuestion to confirm.
>
> 3. New deferred work: Check the diff for TODO, FIXME, HACK, and XXX comments.
>    For each meaningful deferred work, use AskUserQuestion to ask whether it should
>    be captured in TODOS.md.
> ```

**中文**：

TODOS.md 是项目技术债和未来工作的追踪文件（gstack 项目维护的，不是标准 GitHub issue）。

**三个方向的清理**：

```
方向1：已完成但未标记的 TODO
  diff 中有代码变更 → 对应 TODOS.md 条目 → AUTO 标记为已完成

方向2：条目描述过时
  TODO 引用了被重构的文件/组件 → ASK 用户确认是否更新描述

方向3：代码中的新 TODO/FIXME
  diff 中新增了 // TODO: 或 // FIXME: → ASK 用户是否录入 TODOS.md
  门槛：有意义的延期工作（不是临时注释）
```

**保守原则**：只有 diff 中有**明确证据**才标记 TODO 为已完成。模棱两可的不动，避免错误关闭未完成的工作项。

---

## 十二、Step 8：VERSION 管理

> **原文**：
> ```
> CRITICAL — NEVER BUMP VERSION WITHOUT ASKING.
>
> 1. If VERSION does not exist: Skip silently.
>
> 2. Check if VERSION was already modified on this branch:
>    git diff <base>...HEAD -- VERSION
>
> 3. If VERSION was NOT bumped: Use AskUserQuestion:
>    RECOMMENDATION: Choose C (Skip) because docs-only changes rarely warrant a version bump
>    A) Bump PATCH (X.Y.Z+1)
>    B) Bump MINOR (X.Y+1.0)
>    C) Skip — no version bump needed
>
> 4. If VERSION was already bumped: Do NOT skip silently. Check whether the bump
>    still covers the full scope of changes on this branch.
> ```

**中文**：

VERSION 管理是最"敏感"的步骤，因为它影响用户感知和下游依赖。

**已经 bump 过的特殊逻辑**：

> **原文**：
> ```
> a. Read the CHANGELOG entry for the current VERSION. What features does it describe?
> b. Are there significant changes NOT mentioned in the CHANGELOG for the current version?
> c. If covered: Skip — output "VERSION: Already bumped to vX.Y.Z, covers all changes."
> d. If uncovered: AskUserQuestion explaining what's covered vs what's new...
>    The key insight: a VERSION bump set for "feature A" should not silently absorb
>    "feature B" if feature B is substantial enough to deserve its own version entry.
> ```

**中文**：这是一个常被忽视的细节。`/ship` 可能已经把 VERSION 从 1.2.9 → 1.3.0（为 feature A）。但现在的 PR 同时包含了 feature A 和 feature B。如果 CHANGELOG 里 v1.3.0 只描述了 feature A，feature B 就被"隐藏"在版本里了。

**VERSION 决策树**：

```
VERSION 文件存在？
    │
    No → 跳过
    │
    Yes
    │
    VERSION 在本分支被修改过？
    │
    No → AskUserQuestion（推荐C：跳过，文档变更通常不需要版本号）
    │
    Yes
    │
    CHANGELOG 里当前版本描述是否覆盖所有重大变更？
    │
    Yes → 输出 "Already bumped to vX.Y.Z, covers all changes"，跳过
    │
    No → AskUserQuestion（有未覆盖的重大变更，是否 bump 到下一个 patch？）
```

---

## 十三、Step 9：提交与输出

### 13.1 空检查

> **原文**：
> ```
> Empty check first: Run git status (never use -uall). If no documentation files were
> modified by any previous step, output "All documentation is up to date." and exit
> without committing.
> ```

**中文**：如果前面 8 步都没有修改任何文档文件，就不创建空提交。`git status` 不加 `-uall` 是因为 `-uall` 会展开所有 untracked 子目录，在大型 monorepo 里很慢。

### 13.2 提交规范

> **原文**：
> ```bash
> git commit -m "$(cat <<'EOF'
> docs: update project documentation for vX.Y.Z.W
>
> Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
> EOF
> )"
> ```

**中文**：

- `docs:` 前缀遵循 Conventional Commits 规范
- `vX.Y.Z.W` 是当前版本号
- `Co-Authored-By` 标注 Claude 参与，透明度良好
- 只 stage 文档文件（`git add README.md ARCHITECTURE.md CHANGELOG.md ...`），不用 `git add -A`

### 13.3 PR/MR Body 更新（幂等，竞争安全）

> **原文**：
> ```
> 1. Read the existing PR/MR body into a PID-unique tempfile:
>    gh pr view --json body -q .body > /tmp/gstack-pr-body-$$.md
>
> 2. If the tempfile already contains a ## Documentation section, replace it.
>    If not, append a ## Documentation section at the end.
>
> 3. The Documentation section should include a doc diff preview — for each file
>    modified, describe what specifically changed.
>
> 4. Write the updated body back:
>    gh pr edit --body-file /tmp/gstack-pr-body-$$.md
>
> 5. Clean up: rm -f /tmp/gstack-pr-body-$$.md
> ```

**中文**：

**幂等性**：多次运行 `/document-release` 不会重复追加 `## Documentation` 节——先检查是否已存在，存在则替换，不存在才追加。

**竞争安全**：使用 `$$`（当前进程 PID）作为临时文件名后缀，防止多个并发进程相互覆盖。

**GitLab 的特殊处理**：GitLab 的 `glab mr update` 不支持 `--body-file` 参数，必须用 heredoc 传入内容。这要先用 Read 工具读取临时文件，再构建 heredoc 命令：

```bash
# GitHub 方式（简洁）
gh pr edit --body-file /tmp/gstack-pr-body-$$.md

# GitLab 方式（必须用 heredoc 避免 shell 元字符问题）
glab mr update -d "$(cat <<'MRBODY'
<file contents here>
MRBODY
)"
```

**三平台差异对比**：

| 平台 | PR 查看 | PR 更新 | body-file 支持 |
|------|---------|---------|---------------|
| GitHub | `gh pr view --json body` | `gh pr edit --body-file` | 是 |
| GitLab | `glab mr view -F json` | `glab mr update -d "..."` | 否（用 heredoc） |
| Bitbucket | 不支持 | 不支持 | — |

### 13.4 文档健康摘要

> **原文**：
> ```
> Output a scannable summary showing every documentation file's status:
>
> Documentation health:
>   README.md       [status] ([details])
>   ARCHITECTURE.md [status] ([details])
>   CONTRIBUTING.md [status] ([details])
>   CHANGELOG.md    [status] ([details])
>   TODOS.md        [status] ([details])
>   VERSION         [status] ([details])
> ```

**状态值**：

| 状态 | 含义 |
|------|------|
| `Updated` | 有改动，附变更描述 |
| `Current` | 无需变更 |
| `Voice polished` | 仅 CHANGELOG 措辞调整 |
| `Not bumped` | 用户选择不 bump VERSION |
| `Already bumped` | `/ship` 已设置版本号 |
| `Skipped` | 文件不存在 |

**示例输出**：
```
Documentation health:
  README.md       Updated (added /document-release to skills table, count 9→10)
  ARCHITECTURE.md Current (no changes needed)
  CONTRIBUTING.md Updated (fixed bun install → npm install in setup section)
  CHANGELOG.md    Voice polished (2 entries rewritten to user-forward style)
  TODOS.md        Updated (marked "Add document-release skill" as Completed: v1.3.0)
  VERSION         Already bumped (v1.3.0, covers all changes)
```

---

## 十四、重要规则汇总

> **原文**：
> ```
> Important Rules
> - Read before editing. Always read the full content of a file before modifying it.
> - Never clobber CHANGELOG. Polish wording only. Never delete, replace, or regenerate entries.
> - Never bump VERSION silently. Always ask. Even if already bumped, check whether it covers
>   the full scope of changes.
> - Be explicit about what changed. Every edit gets a one-line summary.
> - Generic heuristics, not project-specific. The audit checks work on any repo.
> - Discoverability matters. Every doc file should be reachable from README or CLAUDE.md.
> - Voice: friendly, user-forward, not obscure. Write like you're explaining to a smart person
>   who hasn't seen the code.
> ```

**中文翻译与分析**：

| 规则 | 原因 | 违规后果 |
|------|------|---------|
| 先读后编辑 | 不知道原内容就无法精确 Edit | 可能生成错误的 old_string，Edit 失败 |
| 不覆盖 CHANGELOG | 真实事故：AI 覆盖了历史条目 | 不可逆的历史数据损失 |
| VERSION 必须问用户 | 版本号影响用户感知和依赖管理 | 错误的版本号会误导下游用户 |
| 每次编辑附说明 | 透明度 + 可审查性 | PR reviewer 不知道文档为何变更 |
| 通用启发式规则 | 适用于任何语言/框架的项目 | 过于项目特定则无法泛化 |
| 可发现性 | 孤立文档等于不存在 | 新人找不到重要文档 |
| 用户友好的声音 | CHANGELOG 是给用户看的，不是给工程师 | 用户无法理解发布内容 |

---

## 十五、整体工作流总结

```
用户运行 /document-release
         │
         ▼
  ① Preamble（环境初始化）
    • 更新检查、会话管理
    • 读取 BRANCH、PROACTIVE、learnings
         │
         ▼
  ② Step 0：平台检测
    • GitHub / GitLab / unknown
    • 确定 base branch
         │
         ▼
  ③ Step 1：预检 + Diff 分析
    • 在 feature 分支？（否则 abort）
    • git diff --stat / --oneline / --name-only
    • 发现所有 .md 文件
    • 变更分类（新功能/行为变更/删除/基础设施）
         │
         ▼
  ④ Step 2：逐文件审计
    ┌────────────────────────────────┐
    │ README / ARCHITECTURE /        │
    │ CONTRIBUTING / CLAUDE.md /     │
    │ 其他 .md                       │
    │                                │
    │ 每个文件 → AUTO 或 ASK 分类     │
    └────────────────────────────────┘
         │
         ▼
  ⑤ Step 3：应用 AUTO 更新
    • Edit 工具（精确字符串替换）
    • 每次编辑附一行说明
         │
         ▼
  ⑥ Step 4：处理 ASK 变更
    • AskUserQuestion（逐条）
    • 用户批准后立即应用
         │
         ▼
  ⑦ Step 5：CHANGELOG 声音打磨
    • 只用 Edit（不用 Write）
    • 改措辞，不改内容
    • 用户导向（"You can now..."）
         │
         ▼
  ⑧ Step 6：跨文档一致性检查
    • README vs CLAUDE.md 功能列表
    • ARCHITECTURE vs CONTRIBUTING 结构
    • CHANGELOG 版本 vs VERSION 文件
    • 可发现性检查
         │
         ▼
  ⑨ Step 7：TODOS.md 清理
    • 标记已完成条目
    • 更新过期描述
    • 录入代码中新增的 TODO/FIXME
         │
         ▼
  ⑩ Step 8：VERSION 管理
    • 未 bump → AskUserQuestion（推荐 Skip）
    • 已 bump → 检查是否覆盖全部变更
         │
         ▼
  ⑪ Step 9：提交 + 输出
    • 空检查（无变更 → 不提交）
    • git add（逐文件）+ git commit + git push
    • PR/MR body 追加 ## Documentation 节
    • 输出文档健康摘要
         │
         ▼
  ⑫ Operational Self-Improvement
    • 反思本次会话发现的 operational learning
    • gstack-learnings-log 写入
         │
         ▼
  ⑬ Telemetry
    • 记录运行时长和结果
         │
         ▼
  DONE / DONE_WITH_CONCERNS / BLOCKED
```

---

## 十六、使用建议

**什么时候运行 `/document-release`？**

1. **每次 `/ship` 之后**：这是最自然的时机。PR 已创建，文档还没更新。
2. **PR 合并前的 checklist**：把 `/document-release` 加到 PR 模板的 checklist 里。
3. **发布一个重要版本前**：确保所有文档都反映当前状态。

**不适合的场景**：

- 在 main/master 分支上直接运行（Step 1 会 abort）
- 纯代码重构但没有任何 diff（Step 1 空分析后快速退出）
- 非 gstack 管理的项目（没有 VERSION 文件、TODOS.md 等，会静默跳过对应步骤）

**与 CHANGELOG.md 的注意事项**：

如果你的项目用自动化工具（如 semantic-release、standard-version）管理 CHANGELOG，`/document-release` 的 Step 5 可能冲突。建议在 CLAUDE.md 里注明：
```markdown
## CHANGELOG management
We use semantic-release for CHANGELOG. Do NOT manually edit CHANGELOG.md.
```
这样 `/document-release` 在读到 CLAUDE.md 的这条指令时会跳过 Step 5。

---

*源文件：`/d/transsion/ai/gstack/document-release/SKILL.md`（925 行）*
*注解版本：2026-04-07*
