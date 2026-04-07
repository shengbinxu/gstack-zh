# `/land-and-deploy` 技能逐段中英对照注解

> 对应源文件：[`land-and-deploy/SKILL.md`](https://github.com/garrytan/gstack/blob/main/land-and-deploy/SKILL.md)（1587 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: land-and-deploy
preamble-tier: 4
version: 1.0.0
description: |
  Land and deploy workflow. Merges the PR, waits for CI and deploy,
  verifies production health via canary checks. Takes over after /ship
  creates the PR. Use when: "merge", "land", "deploy", "merge and verify",
  "land it", "ship it to production".
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
---
```

**中文翻译**：

- **preamble-tier: 4**：最高级别的 Preamble（共 4 级）。只有 `/ship`、`/qa`、`/land-and-deploy` 使用 tier 4，因为这些技能会操作生产环境，需要最完整的上下文初始化（repo 检测、学习记录、staging 环境检测等）。
- **description**：合并并部署工作流。合并 PR、等待 CI 和部署、通过 canary 检查验证生产健康状态。接管 `/ship` 创建 PR 之后的工作。
- **allowed-tools**：包含 `Write` 和 `Glob`（用于写部署报告、读取工作流文件），但**没有 Edit**——技能不修改源码，只操作 git/GitHub/deploy 流程。

> **设计原理：与 `/ship` 的职责划分**
> `/ship` 负责：测试 → 代码评审 → 版本号 → CHANGELOG → 创建 PR。
> `/land-and-deploy` 负责：合并 PR → 等待 CI → 等待部署 → 验证生产。
> 这种划分允许用户在创建 PR 后等待他人审查，然后再来合并部署。两个技能可以独立运行。

---

## Preamble 展开区

`land-and-deploy` 使用 **tier 4 Preamble**，这是最完整的版本，额外包含：

- **Context Recovery**：session 压缩后从 `~/.gstack/projects/$SLUG/` 恢复最近的部署历史
- **学习记录加载**：如果该项目有超过 5 条学习记录，自动加载最相关的 3 条
- **SPAWNED_SESSION 处理**：在 AI orchestrator 子 session 中跳过所有交互，自动选择推荐选项

**GitLab 提前退出机制**：

> **原文**：
> ```
> If the platform detected above is GitLab or unknown: STOP with:
> "GitLab support for /land-and-deploy is not yet implemented."
> ```

**中文**：若检测到 GitLab 或未知平台，立即停止并提示用户手动合并。这个提前退出保护了后续步骤不会在错误平台上运行。

---

## 核心角色设定

> **原文**：
> ```
> You are a Release Engineer who has deployed to production thousands of times. You
> know the two worst feelings in software: the merge that breaks prod, and the merge
> that sits in queue for 45 minutes while you stare at the screen. Your job is to
> handle both gracefully.
> ```

**中文**：你是一个部署过数千次生产环境的**发布工程师**。你知道软件里最糟糕的两种感受：破坏生产的合并，以及在队列里等了 45 分钟却没有任何进展的合并。你的工作是优雅地处理这两种情况。

> **设计原理：角色设定的作用**
> 给 AI 设定具体角色会改变其决策风格。"Release Engineer"意味着：重视稳定性、主动叙述进度、在每个失败点提供 revert 选项、第一次运行时教学、后续运行时高效。

---

## 用户调用参数

```
/land-and-deploy           # 自动检测当前分支的 PR，无部署后验证
/land-and-deploy <url>     # 自动检测 PR + 在此 URL 验证部署
/land-and-deploy #123      # 指定 PR 编号
/land-and-deploy #123 <url># 指定 PR + 验证 URL
```

---

## Step 0：平台检测

> **原文**：
> ```
> git remote get-url origin 2>/dev/null
> ```
> GitHub → `gh` CLI；GitLab → 直接 STOP；未知 → git-native fallback

**中文**：技能首先检测 git 托管平台。所有后续步骤（PR 查询、CI 等待、合并命令）都依赖正确的平台识别。GitLab 目前不支持，直接报错退出，避免后续步骤出现奇怪错误。

---

## Step 1：预检（Pre-flight）

> **原文**：
> ```
> Tell the user: "Starting deploy sequence. First, let me make sure everything is
> connected and find your PR."
>
> 1. Check GitHub CLI authentication: gh auth status
> 2. Parse arguments.
> 3. Detect PR from current branch.
> 4. Tell the user what you found.
> 5. Validate PR state.
> ```

**中文**：预检阶段的 4 种 PR 状态处理：

| PR 状态 | 处理方式 |
|--------|---------|
| 无 PR | STOP，提示先运行 `/ship` |
| `MERGED` | 已合并，提示运行 `/canary <url>` 验证 |
| `CLOSED` | 已关闭，提示在 GitHub 上重新打开 |
| `OPEN` | 继续 |

---

## Step 1.5：首次运行的 Dry-run 验证

这是 `land-and-deploy` 最有特色的设计。技能使用**配置指纹**来判断是否需要重新展示部署基础设施。

> **原文**：
> ```
> SAVED_HASH vs CURRENT_HASH (Deploy Configuration in CLAUDE.md)
>            vs WORKFLOW_HASH (deploy-related GitHub Actions files)
> → FIRST_RUN / CONFIRMED / CONFIG_CHANGED
> ```

**中文**：

| 检测结果 | 含义 | 行为 |
|---------|------|------|
| `CONFIRMED` | 之前成功部署过，配置未变 | 跳过干跑，直接进入就绪检查 |
| `CONFIG_CHANGED` | 之前部署过，但配置变了 | 重新展示基础设施 |
| `FIRST_RUN` | 从未运行过 | 完整干跑流程 |

> **设计原理："第一次 = 教学模式，后续 = 高效模式"**
> 第一次部署时，工程师需要了解自己的基础设施、信任工具的判断。之后每次部署，他们只需要确认"CI 通过了，合并"。gstack 通过配置指纹记忆这个状态，在正确的时机切换模式。

**1.5b：基础设施验证表格示例**：

```
╔══════════════════════════════════════════════════════════╗
║         DEPLOY INFRASTRUCTURE VALIDATION                  ║
╠══════════════════════════════════════════════════════════╣
║  Platform:    fly (from fly.toml)                         ║
║  App:         myapp                                       ║
║  Prod URL:    https://myapp.fly.dev                       ║
║                                                           ║
║  COMMAND VALIDATION                                       ║
║  ├─ gh auth status:     ✓ PASS                            ║
║  ├─ fly status:         ✓ PASS                            ║
║  ├─ curl prod URL:      ✓ PASS (200 OK)                   ║
║  └─ deploy workflow:    .github/workflows/deploy.yml      ║
╚══════════════════════════════════════════════════════════╝
```

---

## Step 3.5：合并前就绪门控

这是整个流程的**最关键节点**——合并是不可逆的。

> **原文**：
> ```
> This is the critical safety check before an irreversible merge. The merge cannot
> be undone without a revert commit. Gather ALL evidence, build a readiness report,
> and get explicit user confirmation before proceeding.
> ```

**中文**：合并无法撤销（除非创建 revert commit）。这一步汇总所有证据，给用户看完整的就绪报告，要求明确确认后才合并。

**四项检查**：

| 检查项 | 工具 | 阻断（Blocker）还是警告（Warning）|
|--------|------|--------------------------------|
| 代码评审新鲜度 | `gstack-review-read` | 4+ commits 后 → 警告（可内联复查）|
| 测试结果 | `bun test` + E2E eval 文件 | 失败 → 阻断 |
| PR body 准确性 | `gh pr view --json body` vs `git log` | 陈旧 → 警告 |
| 文档更新 | `git diff --name-only ... README.md CHANGELOG.md` | 未更新 → 警告 |

**就绪报告格式**：

```
╔══════════════════════════════════════════════════════════╗
║              PRE-MERGE READINESS REPORT                  ║
╠══════════════════════════════════════════════════════════╣
║  PR: #42 — feat: add dark mode                           ║
║  Branch: feat/dark-mode → main                           ║
║                                                          ║
║  REVIEWS    Eng: CURRENT | CEO: — | Codex: CURRENT       ║
║  TESTS      Free: PASS | E2E: 52/52 | LLM: PASS          ║
║  DOCS       CHANGELOG: Updated | VERSION: 0.9.8          ║
║  PR BODY    Accuracy: Current                            ║
║                                                          ║
║  WARNINGS: 0  |  BLOCKERS: 0                             ║
╚══════════════════════════════════════════════════════════╝
```

> **设计原理：为什么评审陈旧只是警告而非阻断？**
> 强制阻断会让用户每次都要重跑评审。现实中，如果改动很小（比如修改一个配置值），评审陈旧不一定危险。技能的做法是：陈旧时提供**内联快速评审**选项（约 2 分钟），让用户自己决定是否需要完整评审。

---

## Step 4：合并 PR

> **原文**：
> ```
> Try auto-merge first (respects repo merge settings and merge queues):
> gh pr merge --auto --delete-branch
>
> If --auto is not available:
> gh pr merge --squash --delete-branch
> ```

**中文**：优先尝试 `--auto`（尊重仓库的合并规则和合并队列），不可用则回退到 `--squash`。

**合并队列处理**：

> **原文**：
> ```
> "Your repo uses a merge queue — that means GitHub will run CI one more time on the
> final merge commit before it actually merges. This is a good thing."
> ```

**中文**：合并队列在最终 merge commit 上再跑一次 CI，防止最后时刻的冲突。技能每 30 秒轮询一次，最多等 30 分钟，每 2 分钟给用户一条进度消息。

---

## Step 5-6：部署策略检测与等待

技能使用 `gstack-diff-scope` 分析变更范围，据此决定验证深度：

> **原文**：
> ```
> | Diff Scope        | Canary Depth |
> |-------------------|-------------|
> | SCOPE_DOCS only   | Skip entirely |
> | SCOPE_CONFIG only | Smoke check |
> | SCOPE_BACKEND     | Console + perf |
> | SCOPE_FRONTEND    | Full canary |
> | Mixed scopes      | Full canary |
> ```

**中文**：纯文档改动不需要验证；配置改动只需烟雾测试；前端改动需要全面 canary 验证（截图 + console + 性能）。

**四种部署等待策略**：

| 策略 | 适用平台 | 等待方式 |
|------|---------|---------|
| A：GitHub Actions | 有 deploy workflow | `gh run view` 轮询，最多 20 分钟 |
| B：平台 CLI | Fly.io / Heroku | `fly status` / `heroku releases` |
| C：自动部署平台 | Vercel / Netlify | 等待 60 秒后直接验证 |
| D：自定义钩子 | CLAUDE.md 自定义命令 | 运行自定义命令 |

**Staging-first 选项**：若检测到 staging 环境，技能会提供先部署 staging 再上 production 的选项，最大化安全性。

---

## Step 7：集成 `/canary` 验证

> **原文**：
> ```
> Tell the user: "Deploy is done. Now I'm going to check the live site to make sure
> everything looks good — loading the page, checking for errors, and measuring performance."
> ```

这一步调用 `/canary` 的核心逻辑（单次检查，非持续监控）：

```bash
$B goto <url>          # 访问页面，确认 200 状态
$B console --errors    # 检查 console 错误（Error / Uncaught / TypeError）
$B perf               # 检查加载时间（< 10 秒）
$B text               # 确认页面有内容（非空白/错误页）
$B snapshot -i -a -o ".gstack/deploy-reports/post-deploy.png"  # 留存截图证据
```

> **设计原理：单次检查 vs 持续监控**
> `/land-and-deploy` 的 Step 7 是**单次验证**——确认部署成功。持续监控（每分钟检查，异常报警）是 `/canary` 技能的职责。工作流结束后，技能会建议用户运行 `/canary <url>` 进行扩展监控。

---

## Step 8：Revert（回滚）

> **原文**：
> ```
> git fetch origin <base>
> git checkout <base>
> git revert <merge-commit-sha> --no-edit
> git push origin <base>
> ```

**中文**：若生产健康检查失败，用户可选择立即回滚。`git revert` 创建一个新 commit 来撤销合并，保留历史记录（不是 `git reset`）。若有分支保护，改为创建 revert PR。

---

## Step 9：部署报告

> **原文**：
> ```
> LAND & DEPLOY REPORT
> ═════════════════════
> PR:      #42 — feat: add dark mode
> Branch:  feat/dark-mode → main
> Merged:  2024-01-15 14:32:00 (squash)
> ...
> VERDICT: DEPLOYED AND VERIFIED
> ```

报告保存至 `.gstack/deploy-reports/{date}-pr{number}-deploy.md`，并写一条 JSONL 到 `~/.gstack/projects/$SLUG/`，用于后续的 `/retro` 分析。

---

## 完整流程总结图

```
用户输入 /land-and-deploy [#PR] [url]
         │
         ├─ Step 0：平台检测（GitHub / GitLab→STOP）
         │
         ├─ Step 1：预检
         │     ├─ gh auth 检查
         │     ├─ 查找/验证 PR
         │     └─ PR 状态判断（OPEN→继续，其他→STOP）
         │
         ├─ Step 1.5：首次运行干跑
         │     ├─ CONFIRMED → 跳过，直接进 Step 2
         │     ├─ CONFIG_CHANGED → 重新检测基础设施
         │     └─ FIRST_RUN → 完整干跑（检测平台 / 验证命令 / 检测 staging / 用户确认）
         │
         ├─ Step 2：CI 状态检查
         │     ├─ FAILING → STOP
         │     ├─ PENDING → Step 3 等待
         │     └─ PASS → Step 3.5
         │
         ├─ Step 3：等待 CI（最多 15 分钟）
         │
         ├─ Step 3.5：合并前就绪门控（唯一必须用户确认的步骤）
         │     ├─ 评审新鲜度 / 测试 / PR body / 文档检查
         │     ├─ 构建就绪报告
         │     └─ AskUserQuestion → A合并 / B先修警告 / C强制合并
         │
         ├─ Step 4：合并 PR
         │     ├─ 优先 --auto（支持合并队列）
         │     └─ 回退 --squash（直接合并）
         │
         ├─ Step 5：部署策略检测
         │     └─ 有 staging → 可选先验 staging 再上 prod
         │
         ├─ Step 6：等待部署（Actions / 平台 CLI / 自动部署）
         │     └─ 失败 → AskUserQuestion（查日志 / 回滚 / 继续）
         │
         ├─ Step 7：Canary 验证（调用 browse daemon 单次检查）
         │     └─ 失败 → AskUserQuestion → 可选 Step 8 回滚
         │
         ├─ Step 8：Revert（可选，按需触发）
         │
         └─ Step 9：生成部署报告 + 建议后续操作（/canary / /benchmark）
```

---

## 设计核心思路汇总表

| 设计决策 | 具体实现 | 背后原因 |
|---------|---------|---------|
| 职责切割：接管 `/ship` 之后 | `/ship` 建 PR，`/land-and-deploy` 合并 | 允许人工审查窗口 |
| 配置指纹记忆 | CLAUDE.md + workflow 文件哈希 | 第一次教学，后续高效 |
| diff-scope 驱动验证深度 | `gstack-diff-scope` 分析变更范围 | 文档改动不需要截图验证 |
| 合并前唯一交互门 | Step 3.5 就绪报告 | 只在不可逆操作前要求确认 |
| 合并队列支持 | `--auto` 优先，轮询等待 | 不绕过 repo 的安全规则 |
| 评审陈旧 = 警告非阻断 | 提供内联快速评审选项 | 实用主义：小改动不需要完整评审 |
| 每个失败点提供 revert | AskUserQuestion 带 revert 选项 | 部署是可逆的，工具应该帮你逆 |
| 单次验证，不持续监控 | Step 7 调用 browse 一次 | 持续监控是 `/canary` 的职责 |
| Staging-first 选项 | 检测到 staging 时询问 | 最大化安全：先验后推 |
| 部署报告 + JSONL 日志 | `.gstack/deploy-reports/` + `~/.gstack/projects/` | 支持 `/retro` 分析部署历史 |
