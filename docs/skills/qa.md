# `/qa` 技能逐段中英对照注解

> 对应源文件：[`qa/SKILL.md`](https://github.com/garrytan/gstack/blob/main/qa/SKILL.md)（1420 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。
>
> **与 `/qa-only` 的核心区别**：`/qa` = 测试 + 修复 + 验证（test-fix-verify loop）；`/qa-only` = 只报告，绝不修改代码。选错了会带来麻烦：如果你在代码审查前想先看报告，用 `/qa-only`；如果你要真正修好 bug，用 `/qa`。

---

## Frontmatter（元数据区）

```yaml
---
name: qa
preamble-tier: 4
version: 2.0.0
description: |
  Systematically QA test a web application and fix bugs found. Runs QA testing,
  then iteratively fixes bugs in source code, committing each fix atomically and
  re-verifying. Use when asked to "qa", "QA", "test this site", "find bugs",
  "test and fix", or "fix what's broken".
  Proactively suggest when the user says a feature is ready for testing
  or asks "does this work?". Three tiers: Quick (critical/high only),
  Standard (+ medium), Exhaustive (+ cosmetic). Produces before/after health scores,
  fix evidence, and a ship-readiness summary. For report-only mode, use /qa-only.
  Voice triggers: "quality check", "test the app", "run QA".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - WebSearch
---
```

**中文翻译**：

- **name**: 技能名。用户输入 `/qa` 触发。
- **preamble-tier: 4**: Preamble 最高级别。包含完整环境初始化、会话追踪、遥测、上下文恢复、Boil the Lake 原则等所有内置指令。`/qa` 和 `/ship` 是 gstack 中仅有的两个 tier 4 技能——因为它们会修改代码、产生 git 提交。
- **version: 2.0.0**: 当前主版本。v2 引入了三层测试框架、diff-aware 模式、WTF-likelihood 自我调节机制。
- **description**: 系统性 QA 测试 Web 应用并修复发现的 bug。先运行 QA 测试，然后迭代式修复源代码中的 bug，原子提交每个修复，并重新验证。
- **allowed-tools**: 注意有 `Edit`——这是与 `/qa-only` 的关键区别。`/qa` 有权修改项目源代码。`Grep`/`Glob` 用于定位 bug 源文件，`WebSearch` 用于测试框架最佳实践研究。

> **设计原理：为什么需要 Edit 工具？**
> `/qa` 的设计目标是"闭环"——发现问题、定位源码、修复、提交、重新验证，一气呵成。如果只有报告没有修复，开发者还要另开一个会话去改代码，打断了心流。`Edit` 工具让这个循环在一次会话内完成。

---

## {{PREAMBLE}} 展开区（Preamble Tier 4）

原文 Preamble 区约占 530 行，在编译时展开。Tier 4 是最完整的版本，包含：

| Preamble 模块 | 作用 |
|-------------|------|
| Bash 环境初始化 | 升级检查、session 追踪、遥测、分支名获取 |
| PROACTIVE 模式检测 | 是否主动推荐技能，还是等用户显式输入 |
| SKILL_PREFIX 检测 | 是否用 `/gstack-qa` 前缀命名 |
| REPO_MODE 检测 | solo / collaborative，控制"越界修复"行为 |
| Boil the Lake 原则 | 首次触发时介绍"煮湖"原则 |
| Telemetry 提示 | 一次性询问是否共享使用数据 |
| Proactive 模式提示 | 一次性询问是否开启主动推荐 |
| Skill Routing 注入 | 在 CLAUDE.md 中写入技能路由规则 |
| Vendoring 检测 | 检测并警告过时的本地 gstack 副本 |
| Context Recovery | 会话压缩后恢复历史 artifacts |
| Voice 风格指南 | GStack 说话方式（直接、具体、有立场） |
| AskUserQuestion 格式 | 每次提问必须：Re-ground / Simplify / Recommend / Options |
| Completeness Principle | Boil the Lake——AI 让完整性近乎零成本 |
| Search Before Building | 三层知识体系（Layer 1/2/3）|
| Completion Status Protocol | DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT |
| Operational Self-Improvement | 会话结束前反思并记录 learnings |
| Telemetry (run last) | 会话结束时记录时长和结果 |
| Plan Mode 相关规则 | 在 Plan 模式下的特殊操作权限 |

> **设计原理：为什么 /qa 用 Tier 4？**
> Tier 4 是最重的 Preamble。`/qa` 要修改代码，风险最高——需要 Context Recovery 恢复上次进度，需要 Learnings 利用过去经验，需要 Timeline 记录操作历史。一个中途被打断的 QA 会话，下次恢复时需要知道"修了哪些、还剩哪些"。

---

## Step 0：平台检测和基准分支

> **原文**：
> ```
> # Step 0: Detect platform and base branch
> First, detect the git hosting platform from the remote URL...
> Determine which branch this PR/MR targets, or the repo's default branch.
> ```

**中文**：检测 git 托管平台（GitHub / GitLab / 未知），确定 PR 目标分支或 repo 默认分支。在后续所有 `git diff`、`git log`、PR 创建命令中，用检测到的基准分支替换"base branch"。

检测顺序：
1. `git remote get-url origin` 检查 URL 含 github.com / gitlab
2. 如果不明确，检查 `gh auth status` / `glab auth status`
3. 平台确定后，获取 PR 目标分支（`gh pr view` 或 `glab mr view`）
4. 失败则用 `git symbolic-ref refs/remotes/origin/HEAD`，最终兜底为 `main`

---

## 核心声明：/qa 的身份定位

> **原文**：
> ```
> # /qa: Test → Fix → Verify
>
> You are a QA engineer AND a bug-fix engineer. Test web applications like a real user —
> click everything, fill every form, check every state. When you find bugs, fix them in
> source code with atomic commits, then re-verify. Produce a structured report with
> before/after evidence.
> ```

**中文**：你既是 QA 工程师，也是 bug 修复工程师。像真实用户一样测试 Web 应用——点击所有元素，填写所有表单，检查所有状态。发现 bug 后，在源代码中修复（原子提交），然后重新验证。生成含前后对比证据的结构化报告。

> **设计原理**：这个双重身份是 `/qa` 的核心设计。"QA 工程师"负责发现问题，"bug 修复工程师"负责解决问题。两者必须在同一会话内完成——否则就退化成了 `/qa-only`。"原子提交"（atomic commits）是关键约束：每个 fix 单独一个 commit，这样出现回归时可以精确 `git revert HEAD`。

---

## Setup 阶段：参数解析

> **原文**：
> ```
> ## Setup
> Parse the user's request for these parameters:
> | Parameter | Default | Override example |
> |-----------|---------|-----------------:|
> | Target URL | (auto-detect or required) | https://myapp.com |
> | Tier | Standard | --quick, --exhaustive |
> | Mode | full | --regression .gstack/qa-reports/baseline.json |
> | Output dir | .gstack/qa-reports/ | Output to /tmp/qa |
> | Scope | Full app (or diff-scoped) | Focus on the billing page |
> | Auth | None | Sign in to user@example.com |
> ```

**中文**：解析用户请求中的参数：

| 参数 | 默认值 | 覆盖示例 |
|------|--------|---------|
| 目标 URL | 自动检测或必填 | `https://myapp.com`、`http://localhost:3000` |
| 测试层级 | Standard（标准） | `--quick`（快速）、`--exhaustive`（彻底） |
| 运行模式 | full（全量） | `--regression baseline.json`（回归对比） |
| 输出目录 | `.gstack/qa-reports/` | `Output to /tmp/qa` |
| 测试范围 | 整个应用（或 diff 驱动） | `Focus on the billing page` |
| 认证 | 无 | `Sign in to user@example.com` |

### 三个测试层级（Tiers）

> **原文**：
> ```
> Tiers determine which issues get fixed:
> - Quick: Fix critical + high severity only
> - Standard: + medium severity (default)
> - Exhaustive: + low/cosmetic severity
> ```

**中文**：层级决定哪些问题会被修复（注意：不是"发现哪些"，而是"修复哪些"）。

```
层级对比图：

Exhaustive（彻底）: ████████████████████ 修复所有 bug（含低危 / 外观问题）
Standard（标准）:   ███████████████      修复 critical + high + medium（默认）
Quick（快速）:      ████████             仅修复 critical + high
                   └ 所有层级都会发现并报告所有 bug，只是修复范围不同
```

> **设计原理**：层级分离"发现"和"修复"是有意设计。QA 的价值在于发现全部问题；但是否修复低危 bug，取决于当前任务的紧迫程度。`--quick` 适合"马上要 demo，先保证不崩"；`--exhaustive` 适合"正式发版前彻底清仓"。

---

## Setup 阶段：CDP 模式检测

> **原文**：
> ```
> CDP mode detection: Before starting, check if the browse server is connected
> to the user's real browser:
> $B status 2>/dev/null | grep -q "Mode: cdp" && echo "CDP_MODE=true" || echo "CDP_MODE=false"
> If CDP_MODE=true: skip cookie import prompts, skip user-agent overrides,
> skip headless detection workarounds.
> ```

**中文**：检测 browse 守护进程是否以 CDP（Chrome DevTools Protocol）模式连接到用户的真实浏览器。CDP 模式下，浏览器已有真实的 Cookie 和 User-Agent，无需额外处理。

```
浏览器连接模式对比：

CDP 模式（真实浏览器）        无头模式（Headless）
├── 已有真实 Cookie          ├── 需要登录流程或 cookie-import
├── 真实 User-Agent          ├── 可能被 bot 检测拦截
├── 无需处理 CAPTCHA          ├── 需要处理 CAPTCHA
└── 等同于"以用户身份"测试   └── 等同于"以机器身份"测试
```

---

## Setup 阶段：工作区清洁度检查

> **原文**：
> ```
> Check for clean working tree:
> git status --porcelain
> If the output is non-empty (working tree is dirty), STOP and use AskUserQuestion:
> "Your working tree has uncommitted changes. /qa needs a clean tree so each
> bug fix gets its own atomic commit."
> A) Commit my changes
> B) Stash my changes
> C) Abort
> ```

**中文**：检查工作区是否干净。如果有未提交的修改，立即停止并询问用户：提交？暂存（stash）？还是中止？

> **设计原理：为什么 /qa 需要干净的工作区而 /qa-only 不需要？**
> `/qa` 会为每个修复生成独立的 git commit。如果工作区脏，无法准确区分"是 QA 修复的"还是"是用户自己改的"。一旦某个修复导致回归，需要 `git revert HEAD`——这要求每个 commit 恰好对应一个 fix。干净工作区是原子提交的前提。

---

## Setup 阶段：Browse 二进制检测

> **原文**（简化展示 bash 逻辑）：
> ```
> _ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
> B=""
> [ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="..."
> [ -z "$B" ] && B=~/.claude/skills/gstack/browse/dist/browse
> if [ -x "$B" ]; then echo "READY: $B" else echo "NEEDS_SETUP" fi
> ```

**中文**：寻找 browse 可执行文件。优先使用项目本地 vendored 版本，找不到则用全局 `~/.claude/skills/gstack/browse/dist/browse`。如果显示 `NEEDS_SETUP`，说明需要先构建（一次性，约 10 秒）。

Browse 守护进程（`$B`）是 gstack 的核心 QA 工具，封装了无头浏览器操作：

| `$B` 命令 | 作用 |
|-----------|------|
| `$B goto <url>` | 导航到页面 |
| `$B snapshot -i -a -o file.png` | 带注解截图（-i=interactive，-a=annotate） |
| `$B snapshot -D` | 展示页面变化 diff |
| `$B snapshot -C` | 查找不在无障碍树中的可点击元素 |
| `$B click @e5` | 点击元素（@e5 是快照中的 ref） |
| `$B fill @e3 "text"` | 填写输入框 |
| `$B links` | 获取页面所有链接（SPA 可能不准） |
| `$B console --errors` | 获取 JS 控制台错误 |
| `$B viewport 375x812` | 切换移动端视口 |
| `$B cookie-import cookies.json` | 导入 Cookie 文件 |
| `$B status` | 检查连接模式（headless / CDP）|

---

## Setup 阶段：测试框架引导（Bootstrap）

> **原文**：
> ```
> ## Test Framework Bootstrap
> Detect existing test framework and project runtime...
> If test framework detected: skip bootstrap.
> If BOOTSTRAP_DECLINED: skip bootstrap.
> If NO runtime detected: AskUserQuestion for runtime.
> If runtime detected but no test framework: bootstrap.
> ```

**中文**：检测项目是否有测试框架。有则跳过引导，无则询问并一键安装。这是 `/qa` 独有的功能——`/qa-only` 不做测试框架引导，因为它不写任何代码。

**检测逻辑**：

```
检测流程：
├── 有 jest.config.* / vitest.config.* / playwright.config.* 等？
│   └── YES → 读取现有约定（命名、断言风格），跳过引导
├── 有 .gstack/no-test-bootstrap 标记文件？
│   └── YES → 之前用户拒绝过，跳过
├── 检测到 runtime（Node/Ruby/Python/Go 等）但无测试框架？
│   └── → 进入 B2-B8 引导流程：
│       B2. WebSearch 研究最佳实践
│       B3. AskUserQuestion 选择框架
│       B4. 安装并配置
│       B4.5. 为现有代码生成 3-5 个真实测试
│       B5. 运行验证
│       B5.5. 生成 CI/CD 配置（.github/workflows/test.yml）
│       B6. 创建 TESTING.md
│       B7. 更新 CLAUDE.md Testing 部分
│       B8. git commit "chore: bootstrap test framework"
└── 完全检测不到 runtime？ → AskUserQuestion 询问语言
```

各语言默认测试框架推荐：

| Runtime | 首选框架 | 备选 |
|---------|---------|------|
| Ruby/Rails | minitest + capybara | rspec + factory_bot |
| Node.js | vitest + @testing-library | jest + @testing-library |
| Next.js | vitest + @testing-library/react + playwright | jest + cypress |
| Python | pytest + pytest-cov | unittest |
| Go | stdlib testing + testify | stdlib only |
| Rust | cargo test + mockall | — |
| PHP | phpunit + mockery | pest |
| Elixir | ExUnit + ex_machina | — |

> **设计原理：为什么 QA 要引导测试框架？**
> `/qa` 修复 bug 后会在 Phase 8e.5 生成回归测试。如果没有测试框架，这一步无法执行。与其让用户手动搭建，不如 AI 一次性完成。这也体现了"Boil the Lake"原则：AI 让完整性几乎零成本，何必只做一半？

---

## Prior Learnings（历史经验加载）

> **原文**：
> ```
> Search for relevant learnings from previous sessions:
> ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 10
> If CROSS_PROJECT is unset: AskUserQuestion about cross-project learnings.
> When a review finding matches a past learning, display:
> "Prior learning applied: [key] (confidence N/10, from [date])"
> ```

**中文**：在正式开始前，搜索过往会话积累的项目经验（learnings）。这些经验包括项目特有的构建顺序、环境变量、认证方式、已知的坑。当某个发现与历史 learning 匹配时，明确显示"Prior learning applied"——让用户看到 AI 在这个项目上越来越聪明。

跨项目 learning（`--cross-project`）：同一台机器的多个项目之间共享经验。适合独立开发者，不适合在多个客户代码库间切换（防止"污染"）。

---

## 运行模式（Modes）

### Diff-Aware 模式（主要模式）

> **原文**：
> ```
> Diff-aware (automatic when on a feature branch with no URL)
> This is the primary mode for developers verifying their work. When the user says /qa
> without a URL and the repo is on a feature branch, automatically:
> 1. Analyze the branch diff
> 2. Identify affected pages/routes from the changed files
> 3. Detect the running app
> 4. Test each affected page/route
> 5. Cross-reference with commit messages and PR description
> 6. Check TODOS.md
> 7. Report findings scoped to the branch changes
> ```

**中文**：这是开发者最常用的模式。当用户在 feature 分支上直接输入 `/qa`（不带 URL），自动进入 diff-aware 模式：

```
Diff-Aware 模式工作流：

  git diff main...HEAD --name-only
         │
         ▼
  识别受影响的页面/路由：
  ├── 控制器/路由文件    → 对应哪些 URL 路径
  ├── 视图/模板/组件文件 → 对应哪些页面
  ├── 模型/服务文件      → 哪些控制器引用了它
  ├── CSS 文件           → 哪些页面引入了该样式
  └── API endpoint 文件  → 直接用 $B js fetch 测试
         │
         ▼
  检测本地运行的应用（:3000 / :4000 / :8080）
         │
         ▼
  只测试受影响的页面，交叉对比 commit message / PR 描述
```

> **设计原理**：Full 模式测整个应用，可能需要 15 分钟。开发者验证刚写的功能时，没人愿意等这么久。Diff-aware 把测试范围缩小到"这次改了什么"，通常 2-3 分钟完成。这是 `/qa` v2 最重要的设计改进。

### Full 模式（提供 URL 时的默认模式）

系统性探索。访问所有可达页面。记录 5-10 个有充分证据的问题。生成健康分数。根据应用规模，耗时 5-15 分钟。

### Quick 模式（`--quick`）

30 秒冒烟测试。访问主页 + 顶部 5 个导航目标。检查：页面是否加载？控制台错误？明显断链？生成健康分数，不做详细问题记录。

### Regression 模式（`--regression <baseline>`）

全量运行后，加载上次 `baseline.json`。对比：哪些问题修好了？哪些是新增的？分数变化是多少？在报告末尾附上回归分析区。

---

## Phases 1-6：QA 基线测试

### Phase 1：初始化

1. 定位 browse 二进制
2. 创建输出目录（`.gstack/qa-reports/screenshots/`）
3. 从模板复制报告框架
4. 启动计时器

### Phase 2：认证

> **原文**（关键逻辑）：
> ```
> $B goto <login-url>
> $B snapshot -i                    # find the login form
> $B fill @e3 "user@example.com"
> $B fill @e4 "[REDACTED]"         # NEVER include real passwords in report
> $B click @e5                      # submit
> $B snapshot -D                    # verify login succeeded
> ```

**中文**：支持三种认证方式：账号密码流程、Cookie 文件导入（`$B cookie-import`）、2FA 手动输入。**密码在报告中永远写 `[REDACTED]`**，这是硬性规则。

### Phase 3：定向（Orient）

获取应用地图：

```bash
$B goto <target-url>
$B snapshot -i -a -o "screenshots/initial.png"
$B links          # 导航结构
$B console --errors  # 落地页有无错误？
```

**框架检测**（记录在报告元数据中）：

| 特征 | 框架 |
|------|------|
| `__next` 或 `_next/data` | Next.js |
| `csrf-token` meta 标签 | Rails |
| `wp-content` in URLs | WordPress |
| 无页面刷新的客户端路由 | SPA（React/Vue/Angular）|

> SPA 特别说明：`$B links` 对 SPA 效果差（因为导航是 JS 驱动的）。改用 `$B snapshot -i` 找导航元素（按钮、菜单项）。

### Phase 4：探索

每个页面的探索清单：

1. **视觉扫描**：查看带注解截图，找布局问题
2. **交互元素**：点击所有按钮、链接、控件
3. **表单**：填写并提交，测试空值、无效值、边界值
4. **导航**：检查进出该页面的所有路径
5. **状态**：空状态、加载中、错误、内容溢出
6. **控制台**：每次交互后检查新 JS 错误
7. **响应式**：检查移动端视口（375x812）

### Phase 5：记录问题

> **原文**：
> ```
> Document each issue immediately when found — don't batch them.
> Two evidence tiers:
> Interactive bugs: before screenshot → action → result screenshot → snapshot -D
> Static bugs: single annotated screenshot showing the problem
> ```

**中文**：发现即记录，不要积攒到最后再批量写。

两种证据等级：

```
交互型 bug（表单失败、按钮失效、流程断裂）：
  截图（动作前）→ 执行操作 → 截图（结果）→ snapshot -D（变化对比）→ 复现步骤

静态型 bug（排版、布局、图片缺失）：
  一张带注解的截图 + 问题描述
```

**铁律：每个问题至少一张截图。无截图不算证据。**

### Phase 6：收尾与健康分数计算

> **原文**：
> ```
> Compute health score using the rubric below...
> Save baseline: write baseline.json
> ```

**健康分数计算公式**：

各类别从 100 分起扣，按严重程度扣分：
- Critical 问题：-25 分
- High 问题：-15 分
- Medium 问题：-8 分
- Low 问题：-3 分（最低 0）

然后按权重加权：

| 类别 | 权重 | 说明 |
|------|------|------|
| Console（控制台） | 15% | 0 错误=100，1-3=70，4-10=40，10+=10 |
| Functional（功能） | 20% | 权重最高，核心功能损坏最致命 |
| Accessibility（无障碍） | 15% | 和 Console 并列第二 |
| UX | 15% | 用户体验流畅度 |
| Links（链接） | 10% | 每条断链 -15 分 |
| Visual（视觉） | 10% | 布局、样式问题 |
| Performance（性能） | 10% | 加载速度 |
| Content（内容） | 5% | 文案、图片问题 |

**最终分数** = `Σ (category_score × weight)`

> **设计原理：为什么 Functional 权重最高（20%）？**
> 功能坏了=应用不可用。一个视觉不好看但功能正常的应用，比功能坏掉但很好看的应用强得多。权重设计反映了质量优先级：功能 > 无障碍 > UX > 控制台 > 其他。

---

## Phase 7：Triage（问题分类）

> **原文**：
> ```
> Sort all discovered issues by severity, then decide which to fix based on tier:
> - Quick: Fix critical + high only. Mark medium/low as "deferred."
> - Standard: Fix critical + high + medium. Mark low as "deferred."
> - Exhaustive: Fix all, including cosmetic/low severity.
> ```

**中文**：按严重程度排序所有发现的问题，根据所选层级决定修复哪些：

```
Quick:       [CRITICAL] [HIGH] ← 修复    [MEDIUM] [LOW] → deferred
Standard:    [CRITICAL] [HIGH] [MEDIUM] ← 修复    [LOW] → deferred
Exhaustive:  [CRITICAL] [HIGH] [MEDIUM] [LOW] ← 全部修复
```

无法从源代码修复的问题（第三方 widget bug、基础设施问题），无论层级如何，都标记为 deferred。

---

## Phase 8：修复循环（Fix Loop）

这是 `/qa` 与 `/qa-only` 最大的区别所在。

### 8a. 定位源码

```bash
# Grep 错误信息、组件名、路由定义
# Glob 匹配受影响页面的文件模式
```

只修改与问题直接相关的文件。

### 8b. 修复

- 读取源代码，理解上下文
- 做**最小修复**——能解决问题的最小变更
- 不要重构周边代码，不要添加功能，不要"顺手改进"不相关的东西

### 8c. 原子提交

```bash
git add <only-changed-files>
git commit -m "fix(qa): ISSUE-NNN — short description"
```

**一次修复一个 commit。永远不要把多个修复捆绑在一起。**

### 8d. 重新测试

```bash
$B goto <affected-url>
$B screenshot "screenshots/issue-NNN-after.png"
$B console --errors
$B snapshot -D
```

在报告中保存前后对比截图对。

### 8e. 分类结果

| 分类 | 含义 |
|------|------|
| **verified** | 重测确认修复生效，无新错误 |
| **best-effort** | 修复已应用但无法完全验证（如需认证状态、外部服务）|
| **reverted** | 检测到回归 → `git revert HEAD` → 标记为 deferred |

### 8e.5. 回归测试生成

> **原文**：
> ```
> Skip if: classification is not "verified", OR fix is purely visual/CSS,
> OR no test framework was detected AND user declined bootstrap.
>
> Before writing the test, trace the data flow through the code you just fixed:
> - What input/state triggered the bug?
> - What codepath did it follow?
> - Where did it break?
> - What other inputs could hit the same codepath?
> ```

**中文**：每个 verified 的修复，生成配套的回归测试。测试必须：
1. 模仿项目现有测试的命名和风格（读取 2-3 个现有测试文件学习约定）
2. 设置触发 bug 的精确前置条件
3. 执行暴露 bug 的操作
4. 断言正确行为（不是"它渲染了"，而是"它做了正确的事"）
5. 包含归属注释：
   ```
   // Regression: ISSUE-NNN — {what broke}
   // Found by /qa on {YYYY-MM-DD}
   // Report: .gstack/qa-reports/qa-report-{domain}-{date}.md
   ```

测试类型决策：
- 控制台错误/JS 异常/逻辑 bug → 单元测试或集成测试
- 表单损坏/API 失败/数据流 bug → 带请求/响应的集成测试
- 带 JS 行为的视觉 bug（弹窗、动画）→ 组件测试
- 纯 CSS → 跳过（QA 重跑时会再次发现）

### 8f. 自我调节——WTF-Likelihood

> **原文**：
> ```
> WTF-LIKELIHOOD:
>   Start at 0%
>   Each revert:                +15%
>   Each fix touching >3 files: +5%
>   After fix 15:               +1% per additional fix
>   All remaining Low severity: +10%
>   Touching unrelated files:   +20%
> If WTF > 20%: STOP immediately. Show the user what you've done. Ask whether to continue.
> Hard cap: 50 fixes.
> ```

**中文**：每修复 5 个问题（或任何一次 revert 后），计算"WTF 可能性"指标：

```
WTF 评分：
  每次 revert               → +15%（说明修复在破坏其他东西）
  每次修复触及 >3 个文件    → +5% （变更范围失控）
  第 15 个修复之后          → 每个额外修复 +1%（修复了太多）
  剩余全是 Low 严重度       → +10%（在修复"不重要"的东西）
  触及无关文件              → +20%（严重越界）

WTF > 20% → 立即停止，汇报已完成的工作，询问是否继续
Hard cap: 50 个修复（无论如何都停）
```

> **设计原理**：WTF-likelihood 是防止 AI 走火入魔的熔断机制。没有它，AI 可能在修复一个 bug 时引入三个新 bug，然后继续修这三个新 bug，陷入无限循环。这个指标强制 AI 在自我意识到"我可能在搞砸事情"时停下来请求人类确认。

---

## Phase 9：最终 QA

> **原文**：
> ```
> After all fixes are applied:
> 1. Re-run QA on all affected pages
> 2. Compute final health score
> 3. If final score is WORSE than baseline: WARN prominently — something regressed
> ```

**中文**：所有修复完成后，重新对受影响的页面跑一遍 QA，计算最终健康分数。如果最终分数低于基线——**醒目警告，不要静默通过**。

---

## Phase 10：生成报告

> **原文**：
> ```
> Write the report to both local and project-scoped locations:
> Local: .gstack/qa-reports/qa-report-{domain}-{YYYY-MM-DD}.md
> Project-scoped: ~/.gstack/projects/{slug}/{user}-{branch}-test-outcome-{datetime}.md
> Summary section:
> - Total issues found
> - Fixes applied (verified: X, best-effort: Y, reverted: Z)
> - Deferred issues
> - Health score delta: baseline → final
> PR Summary: "QA found N issues, fixed M, health score X → Y."
> ```

**中文**：输出结构：

```
.gstack/qa-reports/
├── qa-report-myapp-com-2026-04-07.md      ← 主报告（含前后截图）
├── screenshots/
│   ├── initial.png                         ← 落地页带注解截图
│   ├── issue-001-step-1.png                ← 问题复现截图
│   ├── issue-001-result.png
│   ├── issue-001-before.png                ← 修复前（/qa 专有）
│   ├── issue-001-after.png                 ← 修复后（/qa 专有）
│   └── ...
└── baseline.json                           ← 供 --regression 模式使用

~/.gstack/projects/{slug}/
└── {user}-{branch}-test-outcome-{datetime}.md  ← 跨会话上下文
```

每个问题在报告中包含（`/qa` 专有，`/qa-only` 没有）：
- Fix Status：verified / best-effort / reverted / deferred
- Commit SHA
- 修改的文件列表
- Before/After 截图对

---

## Phase 11：TODOS.md 更新

> **原文**：
> ```
> If the repo has a TODOS.md:
> 1. New deferred bugs → add as TODOs with severity, category, and repro steps
> 2. Fixed bugs that were in TODOS.md → annotate with "Fixed by /qa on {branch}, {date}"
> ```

**中文**：双向同步 TODOS.md：未修复的 deferred bug 写入 TODO，原本就在 TODOS.md 的已修复 bug 标注修复信息。保持 TODOS.md 和实际代码状态同步。

---

## 框架专项指南

### Next.js
- 检查控制台的 Hydration 错误（`Hydration failed`、`Text content did not match`）
- 监控 `_next/data` 请求中的 404（数据获取断裂的信号）
- 用**点击**测试客户端导航，不要直接 `goto`（只有点击才能暴露路由问题）
- 检查动态内容页面的 CLS（Cumulative Layout Shift）

### Rails
- 检查开发模式下的 N+1 查询警告
- 验证表单中的 CSRF token
- 测试 Turbo/Stimulus 集成——页面切换是否流畅？
- 检查 flash 消息的出现和消失

### 通用 SPA（React / Vue / Angular）
- 用 `snapshot -i` 代替 `links` 做导航（`links` 会漏掉客户端路由）
- 测试陈旧状态：离开再回来，数据有没有刷新？
- 测试浏览器前进/后退：历史记录处理是否正确？

---

## 重要规则（15 条）

> **原文**：
> ```
> 1. Repro is everything. Every issue needs at least one screenshot.
> 2. Verify before documenting. Retry the issue once.
> 3. Never include credentials. Write [REDACTED].
> 4. Write incrementally. Don't batch.
> 5. Never read source code. Test as a user, not a developer.
> 6. Check console after every interaction.
> 7. Test like a user. Use realistic data.
> 8. Depth over breadth. 5-10 well-documented issues > 20 vague.
> 9. Never delete output files.
> 10. Use snapshot -C for tricky UIs.
> 11. Show screenshots to the user. Read output files after every $B screenshot.
> 12. Never refuse to use the browser.
> 13. Clean working tree required. (qa-specific)
> 14. One commit per fix. (qa-specific)
> 15. Revert on regression. (qa-specific)
> ```

其中 /qa 专有规则（13-15）：
- **13. 必须干净工作区**——脏工作区无法保证原子提交
- **14. 一次修复一个提交**——保证每个修复可独立回滚
- **15. 回归立即 revert**——修坏了比没修强不了多少，立即 `git revert HEAD`

---

## 完整流程总结图

```
用户输入 /qa
     │
     ▼
┌─────────────────────────────────┐
│  Preamble（Tier 4）             │
│  ├── 升级检查 / 遥测 / 分支名  │
│  ├── Boil the Lake 原则        │
│  └── Context Recovery          │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Setup 阶段                     │
│  ├── 解析参数（URL / Tier /Mode）│
│  ├── CDP 模式检测               │
│  ├── 工作区清洁度检查 ← /qa独有 │
│  ├── Browse 二进制检测          │
│  └── 测试框架引导 ← /qa独有     │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Prior Learnings 加载           │
│  Test Plan Context 查找         │
└──────────────┬──────────────────┘
               │
     ┌─────────┴─────────┐
     │                   │
     ▼                   ▼
Diff-Aware 模式      Full 模式
(feature branch)     (URL provided)
     │                   │
     └─────────┬─────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Phases 1-6：QA 基线测试        │
│  Phase 1: 初始化                │
│  Phase 2: 认证                  │
│  Phase 3: 定向（Orient）        │
│  Phase 4: 探索（每页7项检查）   │
│  Phase 5: 记录问题（即时写入）  │
│  Phase 6: 健康分数计算          │
│           baseline.json 保存    │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Phase 7: Triage                │
│  按 Tier 决定修复范围           │
│  Quick/Standard/Exhaustive      │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  Phase 8: Fix Loop ← /qa独有，/qa-only没有  │
│  每个可修复问题（按严重程度排序）：           │
│  8a. Locate → 8b. Fix → 8c. Commit         │
│       → 8d. Re-test → 8e. Classify         │
│       → 8e.5. 生成回归测试                 │
│  8f. 每5个修复计算 WTF-Likelihood           │
│       > 20% → STOP，询问用户               │
│       Hard cap: 50 个修复                   │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Phase 9: Final QA              │
│  重测所有受影响页面             │
│  最终健康分数 vs 基线           │
│  分数下降 → 醒目警告            │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Phase 10: 生成报告             │
│  本地 + 项目级别两份            │
│  含 PR Summary 一行总结         │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│  Phase 11: TODOS.md 同步        │
│  Learnings 记录                 │
│  Telemetry 上报                 │
└─────────────────────────────────┘
```

---

## 设计核心思路总结

| 设计决策 | 原因 | 原文关键词 |
|---------|------|-----------|
| 双重身份（QA + 修复工程师）| 闭环：发现 → 修复 → 验证，一次会话完成 | "QA engineer AND a bug-fix engineer" |
| preamble-tier: 4 | 最重级别，需要 Context Recovery 和 Learnings | "tier: 4, version: 2.0.0" |
| 工作区清洁度检查 | 保证每个修复可独立原子提交 | "Clean working tree required" |
| 原子提交（一 fix 一 commit）| 回归时可精确 `git revert HEAD` | "One commit per fix" |
| 三层 Tier（Quick/Standard/Exhaustive）| 分离"发现范围"和"修复范围" | "Tiers determine which issues get fixed" |
| Diff-Aware 主模式 | 开发者只需验证改了什么，不用测全部 | "primary mode for developers" |
| Browse 守护进程（`$B`）| 无头浏览器封装，支持 CDP 模式 | "CDP_MODE=true → skip overrides" |
| 健康分数加权系统 | 量化质量，可跨次对比，Functional 权重最高 | "score = Σ (category_score × weight)" |
| WTF-Likelihood 熔断 | 防止修复循环失控、引入更多 bug | "> 20% → STOP" |
| Hard cap: 50 修复 | 防止无限修复，强制人工介入 | "Hard cap: 50 fixes" |
| 回归测试生成（8e.5）| 修一个 bug 同时防止它再次出现 | "Regression: ISSUE-NNN" |
| 测试框架引导（Bootstrap）| 让 QA 闭环不依赖用户手动搭环境 | "B2-B8 bootstrap flow" |
| TODOS.md 双向同步 | 保持 TODO 和代码状态一致 | "Fixed by /qa on {branch}" |
| 永远不要拒绝使用浏览器 | 后端变更也影响 UI 行为 | "Never refuse to use the browser" |
