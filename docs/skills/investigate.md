# `/investigate` 技能逐段中英对照注解

> 对应源文件：[`investigate/SKILL.md`](https://github.com/garrytan/gstack/blob/main/investigate/SKILL.md)（776 行含 Preamble 展开）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: investigate
preamble-tier: 2
version: 1.0.0
description: |
  Systematic debugging with root cause investigation. Four phases: investigate,
  analyze, hypothesize, implement. Iron Law: no fixes without root cause.
  Use when asked to "debug this", "fix this bug", "why is this broken",
  "investigate this error", or "root cause analysis".
  Proactively invoke this skill (do NOT debug directly) when the user reports
  errors, 500 errors, stack traces, unexpected behavior, "it was working
  yesterday", or is troubleshooting why something stopped working. (gstack)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
  - WebSearch
hooks:
  PreToolUse:
    - matcher: "Edit"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/../freeze/bin/check-freeze.sh"
          statusMessage: "Checking debug scope boundary..."
    - matcher: "Write"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/../freeze/bin/check-freeze.sh"
          statusMessage: "Checking debug scope boundary..."
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/investigate` 触发，或由 AI 在检测到 bug/错误时自动触发。
- **preamble-tier: 2**: Preamble 详细度级别 2（共 4 级）。比 plan 类技能低一级——调试需要快速行动，减少引导式对话。
- **description 关键句**："Proactively invoke this skill (do NOT debug directly)"——明确禁止 AI 不调用技能直接调试。AI 默认会"顺手修"，这句话阻断了这个直觉。
- **allowed-tools**: 包含 Edit 和 Write——这是调试技能，需要修代码。与只读的 plan-eng-review 形成对比。
- **hooks / PreToolUse**: 在每次 Edit/Write **之前**自动运行 `check-freeze.sh`。这是本技能最独特的机制——物理级别的范围保护。

> **设计原理：为什么有 hooks 但 plan-eng-review 没有？**
> `/investigate` 有 Edit 权限，但调试的高风险在于"顺手改了不相关的代码"。hooks 是门卫——不是靠 AI 自律，而是在 OS 层拦截每次写操作，检查目标文件是否在允许范围内。这是 gstack 中最硬的安全机制之一。

---

## {{PREAMBLE}} 展开区

Preamble 是运行时动态插入的前置脚本，tier 2 包含：

**1. 环境初始化脚本（bash）**

脚本的核心作用：
- 检查 gstack 升级 (`gstack-update-check`)
- 创建 session 文件、清理 2 小时外的旧 session
- 读取 `PROACTIVE`、`SKILL_PREFIX`、`BRANCH` 等环境变量
- 检测 `REPO_MODE`（是否在 git 仓库内）
- 记录遥测起始时间戳 `_TEL_START`
- 加载项目历史 learnings（`gstack-learnings-search`）
- 写入 timeline 日志（`gstack-timeline-log`）
- 检测 `CLAUDE.md` 是否有 skill routing 规则
- 检测是否有 vendored gstack（已废弃）

> **设计原理**：Preamble 是 gstack 的"引擎启动序列"。每次技能运行都从同一个基线开始，确保 AI 知道当前分支、repo 类型、用户偏好和历史学习。这些信息不靠用户手动提供——脚本自动探测。

**2. PROACTIVE 模式控制**

> **原文**：
> ```
> If `PROACTIVE` is `"false"`, do not proactively suggest gstack skills AND do not
> auto-invoke skills based on conversation context. Only run skills the user explicitly
> types (e.g., /qa, /ship).
> ```

**中文**：如果 `PROACTIVE` 为 `false`，不主动建议 gstack 技能，也不基于对话上下文自动触发技能。只运行用户明确输入的技能（如 `/qa`、`/ship`）。

> **设计原理**：用户可能不想要"AI 自动跳出来"的行为。`PROACTIVE=false` 是完全静默模式——AI 会在本应自动触发时说"我觉得 /investigate 可能有用——要不要我运行它？"，然后等待确认。

**3. Boil the Lake 原则**

> **原文**：
> ```
> If `LAKE_INTRO` is `no`: Before continuing, introduce the Completeness Principle.
> Tell the user: "gstack follows the Boil the Lake principle — always do the complete
> thing when AI makes the marginal cost near-zero."
> ```

**中文**：如果是首次运行（未见过 Boil the Lake 介绍），在继续前先介绍完整性原则：当 AI 让边际成本趋近于零时，永远选择做完整的事。只会出现一次。

**4. 历史 Learnings 加载**

脚本会在 Phase 1 之前自动搜索过去会话积累的知识：
```bash
~/.claude/skills/gstack/bin/gstack-learnings-search --limit 3
```
如果 learnings 数量 > 5，会自动显示最相关的 3 条。这让 AI 在调试开始前就知道"这个项目以前踩过哪些坑"。

---

## Voice（声音风格）

> **原文**：
> ```
> Lead with the point. Say what it does, why it matters, and what changes for the builder.
> Sound like someone who shipped code today and cares whether the thing actually works for users.
> ```

**中文**：先说重点。说清楚它做什么、为什么重要、对开发者意味着什么变化。听起来像一个今天刚上线了代码、真的在乎用户体验的人。

> **原文（具体度标准）**：
> ```
> Concreteness is the standard. Name the file, the function, the line number.
> Show the exact command to run... not "there's an issue in the auth flow" but
> "auth.ts:47, the token check returns undefined when the session expires."
> ```

**中文**：具体性是标准。说出文件名、函数名、行号。不是"auth 流程有问题"，而是 `auth.ts:47，token check 在 session 过期时返回 undefined`。

> **设计原理**：Voice 不是风格指南——它直接影响调试报告的质量。要求说出具体行号，意味着 AI 不能用含糊语言蒙混过关。在 Phase 5 的 DEBUG REPORT 里，每一行都要有具体的文件:行号引用。

**Tone 禁止使用的词汇**（AI 词汇黑名单）：

| 类型 | 禁用词 |
|------|--------|
| AI 腔 | delve, robust, comprehensive, nuanced, multifaceted, pivotal, tapestry |
| 连接词滥用 | furthermore, moreover, additionally, underscore, foster |
| 俗语 | "here's the kicker", "plot twist", "the bottom line" |
| Em dash | — （用逗号或句号替代） |

---

## Context Recovery（上下文恢复）

> **原文**：
> ```
> After compaction or at session start, check for recent project artifacts.
> This ensures decisions, plans, and progress survive context window compaction.
> ```

**中文**：在上下文压缩后或会话开始时，检查最近的项目产物。确保决策、计划和进度能在上下文窗口压缩后存活。

恢复脚本读取：
- `~/.gstack/projects/{slug}/ceo-plans/` 最近 3 个文件
- `~/.gstack/projects/{slug}/checkpoints/` 最新 checkpoint
- `~/.gstack/projects/{slug}/timeline.jsonl` 最后 5 条事件

> **设计原理**：Claude 的上下文窗口是有限的。当会话很长时，早期内容会被压缩丢失。Context Recovery 是防灾机制——把关键进度持久化到本地文件，重启后自动重建状态。对于耗时长的 bug 调查尤为重要。

---

## AskUserQuestion 格式规范

> **原文**：
> ```
> ALWAYS follow this structure for every AskUserQuestion call:
> 1. Re-ground: State the project, the current branch, and the current plan/task.
> 2. Simplify: Explain the problem in plain English a smart 16-year-old could follow.
> 3. Recommend: RECOMMENDATION: Choose [X] because [one-line reason]
> 4. Options: Lettered options: A) ... B) ... C) ...
> ```

**中文**：每次 AskUserQuestion 必须遵守：① 重新定位（项目/分支/任务）② 用 16 岁能懂的语言解释 ③ 给出明确推荐 ④ 字母选项。

> **设计原理**："用 16 岁能懂的语言"不是指简化技术——而是禁止直接抛出函数名和内部术语。假设用户已经 20 分钟没看这个窗口了，AI 必须重建上下文，而不是默认用户记得所有细节。

---

## 核心机制：Iron Law（铁律）

> **原文**：
> ```
> # Systematic Debugging
>
> ## Iron Law
>
> NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.
>
> Fixing symptoms creates whack-a-mole debugging. Every fix that doesn't address
> root cause makes the next bug harder to find. Find the root cause, then fix it.
> ```

**中文**：系统性调试。**铁律：没有根因调查，不准修复。** 修症状创造打地鼠式调试。每一个不解决根因的修复都让下一个 bug 更难找。先找根因，再修复。

> **设计原理：为什么这是"铁律"而不是"原则"？**
>
> AI 的默认本能是"看到错误信息就想解决它"。这符合人类对"帮助"的直觉期待。但在软件工程中，修症状是技术债的主要来源：
>
> ```
> 修症状的恶性循环：
>
> 错误 A → 快速修症状 → 错误 B 出现
>     ↑                          │
>     └──────────────────────────┘
>       症状修了，根因还在，B 是 A 的新症状
> ```
>
> 铁律通过明确的全大写"NO FIXES"把这条规则变成不可协商的约束，而不是"建议"。它是整个技能的基础假设。

---

## Phase 1：Root Cause Investigation（根因调查）

> **原文**：
> ```
> ## Phase 1: Root Cause Investigation
>
> Gather context before forming any hypothesis.
>
> 1. Collect symptoms: Read the error messages, stack traces, and reproduction steps.
>    If the user hasn't provided enough context, ask ONE question at a time via AskUserQuestion.
>
> 2. Read the code: Trace the code path from the symptom back to potential causes.
>    Use Grep to find all references, Read to understand the logic.
>
> 3. Check recent changes:
>    git log --oneline -20 -- <affected-files>
>    Was this working before? What changed? A regression means the root cause is in the diff.
>
> 4. Reproduce: Can you trigger the bug deterministically? If not, gather more evidence
>    before proceeding.
> ```

**中文**：在形成任何假设之前先收集上下文。

| 步骤 | 行动 | 工具 |
|------|------|------|
| 1. 收集症状 | 读错误信息、堆栈跟踪、复现步骤。缺少上下文时，每次只问一个问题 | AskUserQuestion |
| 2. 读代码 | 从症状往回追溯代码路径到潜在根因 | Grep、Read |
| 3. 检查最近变更 | `git log --oneline -20` 是不是回归？根因在 diff 里 | Bash |
| 4. 复现 | 能确定性地触发 bug 吗？不能就继续收集证据 | Bash |

**输出**：**"根因假设：..."**——一个关于什么出了问题、为什么的具体可测试的声明。

> **设计原理**："ask ONE question at a time"——不是"一次性发一大堆问题"。人类面对 10 个问题时会选择性回答，而且会觉得被轰炸。AI 应该像侦探一样一步一步收集线索，每轮只问最关键的那个问题。

**Prior Learnings（历史学习加载）**

> **原文**：
> ```
> Search for relevant learnings from previous sessions:
>
> if [ "$_CROSS_PROJ" = "true" ]; then
>   ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 10 --cross-project
> else
>   ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 10
> fi
>
> If learnings are found, display:
> "Prior learning applied: [key] (confidence N/10, from [date])"
> ```

**中文**：在 Phase 1 结束时搜索过去会话积累的学习。如果开启了跨项目学习，会搜索同一台机器上所有项目的历史经验。命中时显示："**先前学习已应用：[key]（置信度 N/10，来自 [date]）**"

> **设计原理**："跨项目学习"是微妙的设计——它让 gstack 在不同代码库之间传递知识。比如你在项目 A 发现了 Redis 连接池的某个坑，下次在项目 B 调试类似问题时 AI 会自动提示。但对多客户开发者要谨慎——可能造成信息污染，所以这是可选的。

---

## Scope Lock（范围锁定）

> **原文**：
> ```
> ## Scope Lock
>
> After forming your root cause hypothesis, lock edits to the affected module
> to prevent scope creep.
>
> If FREEZE_AVAILABLE: Identify the narrowest directory containing the affected files.
> Write it to the freeze state file:
>   echo "<detected-directory>/" > "$STATE_DIR/freeze-dir.txt"
>   echo "Debug scope locked to: <detected-directory>/"
>
> Tell the user: "Edits restricted to <dir>/ for this debug session."
> ```

**中文**：形成根因假设后，把编辑权限锁定到受影响模块，防止范围蔓延。找到包含受影响文件的最窄目录，写入 freeze 状态文件。告知用户：`src/auth/` 已锁定，不能改这个目录以外的文件。运行 `/unfreeze` 解除限制。

> **设计原理**：Scope Lock 与 Frontmatter 里的 hooks 形成完整的二层保护：
>
> ```
> 层 1 - 软约束：AI 知道应该只改受影响模块
> 层 2 - 硬约束：freeze hook 在每次 Edit/Write 前检查文件路径
>                 如果路径不在 freeze-dir.txt 里，操作被阻断
> ```
>
> "最窄目录"是关键策略——不锁 `src/`，而是锁 `src/auth/`。范围越窄，意外改动的可能性越小。

**跳过条件**：
- `FREEZE_UNAVAILABLE`：freeze 脚本不存在，跳过锁定，编辑无限制。
- bug 跨越整个 repo 或范围真的不明确：跳过，并说明原因。

---

## Phase 2：Pattern Analysis（模式分析）

> **原文**：
> ```
> ## Phase 2: Pattern Analysis
>
> Check if this bug matches a known pattern:
>
> | Pattern | Signature | Where to look |
> |---------|-----------|---------------|
> | Race condition | Intermittent, timing-dependent | Concurrent access to shared state |
> | Nil/null propagation | NoMethodError, TypeError | Missing guards on optional values |
> | State corruption | Inconsistent data, partial updates | Transactions, callbacks, hooks |
> | Integration failure | Timeout, unexpected response | External API calls, service boundaries |
> | Configuration drift | Works locally, fails in staging/prod | Env vars, feature flags, DB state |
> | Stale cache | Shows old data, fixes on cache clear | Redis, CDN, browser cache, Turbo |
> ```

**中文翻译与扩展**：

| 模式 | 特征信号 | 查找方向 | 典型表现 |
|------|---------|---------|---------|
| 竞态条件 | 间歇性、时序相关 | 共享状态的并发访问 | 高并发下偶发失败 |
| 空值/null 传播 | NoMethodError、TypeError | 可选值缺少守卫 | 链式调用中任一环节为 null |
| 状态损坏 | 数据不一致、部分更新 | 事务、回调、hooks | 写入后读出的数据不对 |
| 集成失败 | 超时、意外响应 | 外部 API、服务边界 | 本地好、staging 不行 |
| 配置漂移 | 本地好、线上不行 | 环境变量、feature flags、DB 状态 | "我这里没问题" |
| 缓存陈旧 | 显示旧数据、清缓存后好了 | Redis、CDN、浏览器缓存 | 更新了数据但页面没变 |

> **设计原理**：这张表是"经验结晶"——把有经验的工程师脑子里的模式识别显式化。新手看到 TypeError 会去找类型定义；有经验的人会问"这是 null 传播吗？"。把这六种模式内置进技能，让 AI 跳过了积累经验的阶段，直接以高手的角度排查。

**额外检查**：
- `TODOS.md` 里是否有相关已知问题
- `git log` 查同一文件的历史修复——**同一文件反复出现 bug 是架构异味，不是巧合**

**外部模式搜索**（WebSearch）：

> **原文**：
> ```
> External pattern search: If the bug doesn't match a known pattern above, WebSearch for:
> - "{framework} {generic error type}" — sanitize first: strip hostnames, IPs,
>   file paths, SQL, customer data. Search the error category, not the raw message.
> ```

**中文**：如果 bug 不匹配已知模式，WebSearch 搜索通用错误类型。**必须先脱敏**——去掉主机名、IP、文件路径、SQL 片段、客户数据。搜索错误类别，不是原始错误信息。

> **设计原理**：脱敏要求不是可选的——把包含内部路径、客户数据的错误信息直接粘贴到搜索引擎是安全风险。gstack 要求先把私有信息替换为通用描述，再搜索。

---

## Phase 3：Hypothesis Testing（假设检验）

> **原文**：
> ```
> ## Phase 3: Hypothesis Testing
>
> Before writing ANY fix, verify your hypothesis.
>
> 1. Confirm the hypothesis: Add a temporary log statement, assertion, or debug output
>    at the suspected root cause. Run the reproduction. Does the evidence match?
>
> 2. If the hypothesis is wrong: Before forming the next hypothesis, consider searching
>    for the error. Sanitize first... Then return to Phase 1. Gather more evidence.
>    Do not guess.
>
> 3. 3-strike rule: If 3 hypotheses fail, STOP. Use AskUserQuestion:
>    3 hypotheses tested, none match. This may be an architectural issue
>    rather than a simple bug.
>    A) Continue investigating — I have a new hypothesis: [describe]
>    B) Escalate for human review — this needs someone who knows the system
>    C) Add logging and wait — instrument the area and catch it next time
> ```

**中文**：在写任何修复之前先验证假设。

**假设检验循环**：

```
形成假设
    │
    ▼
加临时日志/断言/调试输出（不是真正的修复！）
    │
    ▼
运行复现
    │
    ├─ 证据吻合？──→ YES → 根因确认，进入 Phase 4
    │
    └─ NO
         │
         ▼
    脱敏后 WebSearch
         │
         ▼
    回到 Phase 1 收集更多证据（第 N 次失败）
         │
         ▼
    第 3 次失败？──→ YES → STOP，AskUserQuestion
                           A) 我有新假设
                           B) 升级给人工审查
                           C) 加日志等下次
```

**3-strike 选项 C 的设计**：

> **设计原理**：选项 C "加日志等下次" 看起来是"放弃"，但实际上是间歇性 bug 的正确处理方式。间歇性 bug 往往无法在当场复现——强行修复反而危险。加足够的日志，等 bug 再次发生时有充足数据，再诊断。务实，不是投降。

**Red Flags（AI 自我检测）**：

> **原文**：
> ```
> Red flags — if you see any of these, slow down:
> - "Quick fix for now" — there is no "for now." Fix it right or escalate.
> - Proposing a fix before tracing data flow — you're guessing.
> - Each fix reveals a new problem elsewhere — wrong layer, not wrong code.
> ```

**中文**：

| 危险信号 | 含义 |
|---------|------|
| "Quick fix for now" | 没有"先这样"。要么修对，要么升级。 |
| 没追溯数据流就提 fix | 你在猜。 |
| 每次修复暴露新问题 | 层错了，不是代码错了。 |

> **设计原理**：这三条 Red Flags 是给 AI 的自我监控指令。传统代码审查只检查别人的代码——这里 AI 被要求检查自己的行为模式。当 AI 发现自己在说"for now"，必须停下来质问自己：我是在修症状还是根因？

---

## Phase 4：Implementation（实现修复）

> **原文**：
> ```
> ## Phase 4: Implementation
>
> Once root cause is confirmed:
>
> 1. Fix the root cause, not the symptom. The smallest change that eliminates
>    the actual problem.
>
> 2. Minimal diff: Fewest files touched, fewest lines changed. Resist the urge
>    to refactor adjacent code.
>
> 3. Write a regression test that:
>    - Fails without the fix (proves the test is meaningful)
>    - Passes with the fix (proves the fix works)
>
> 4. Run the full test suite. Paste the output. No regressions allowed.
>
> 5. If the fix touches >5 files: Use AskUserQuestion to flag the blast radius.
> ```

**中文**：根因确认后才能修复。

**4 条实现规则**：

| 规则 | 违反迹象 | 正确做法 |
|------|---------|---------|
| 修根因，不是症状 | 每次修完又冒出新问题 | 追溯到真正失效的那行 |
| 最小 diff | 顺手重构了周边代码 | 克制，只改必要的部分 |
| 回归测试先失败再通过 | 测试直接通过（没有先 fail） | 确认测试在无修复时 FAIL |
| 完整测试套件 | 只跑了相关测试 | 全跑，粘贴输出 |

**>5 文件触发 AskUserQuestion**：

> **原文**：
> ```
> If the fix touches >5 files: Use AskUserQuestion to flag the blast radius:
>   This fix touches N files. That's a large blast radius for a bug fix.
>   A) Proceed — the root cause genuinely spans these files
>   B) Split — fix the critical path now, defer the rest
>   C) Rethink — maybe there's a more targeted approach
> ```

**中文**：修复涉及超过 5 个文件时，这是大爆炸半径。选项：A) 继续（根因真的跨这些文件）B) 拆分（先修主路径）C) 重新想想（是否有更精准的方式）。

> **设计原理**：5 文件阈值是经验规则。普通 bug 修复通常只涉及 1-3 个文件。超过 5 个文件的修复通常意味着要么发现了架构问题（应该升级而不是修），要么 AI 走偏了（在修不相关的代码）。强制暂停，让人类判断。

---

## Phase 5：Verification & Report（验证与报告）

> **原文**：
> ```
> ## Phase 5: Verification & Report
>
> Fresh verification: Reproduce the original bug scenario and confirm it's fixed.
> This is not optional.
>
> Run the test suite and paste the output.
>
> Output a structured debug report:
> DEBUG REPORT
> ════════════════════════════════════════
> Symptom:         [what the user observed]
> Root cause:      [what was actually wrong]
> Fix:             [what was changed, with file:line references]
> Evidence:        [test output, reproduction attempt showing fix works]
> Regression test: [file:line of the new test]
> Related:         [TODOS.md items, prior bugs in same area, architectural notes]
> Status:          DONE | DONE_WITH_CONCERNS | BLOCKED
> ════════════════════════════════════════
> ```

**中文**：

**新鲜验证**：重新复现原始 bug 场景，确认已修复。不可选——必须做。

**DEBUG REPORT 各字段解读**：

| 字段 | 要求 | 错误示范 | 正确示范 |
|------|------|---------|---------|
| Symptom | 用户看到了什么 | "有错误" | "用户点击登录后看到 500 页面" |
| Root cause | 实际什么出了问题 | "auth 有问题" | "`auth.ts:47` token 在 session 过期时返回 `undefined`" |
| Fix | 改了什么，有文件:行号 | "修了 auth 逻辑" | "`auth.ts:47` 加了 `?? ''` 空值守卫" |
| Evidence | 测试输出 + 复现证明 | "测试通过了" | 粘贴完整测试输出 |
| Regression test | 新测试的位置 | "写了测试" | `auth.test.ts:123 "should handle expired session"` |
| Related | 相关 TODO、同区域历史 bug | （省略） | "同区域在 #234 有类似修复，可能是架构问题" |
| Status | 三态之一 | （省略） | `DONE_WITH_CONCERNS` |

**Status 三态**：

| 状态 | 含义 | 用于 |
|------|------|------|
| DONE | 根因找到，修复应用，回归测试写好，全部测试通过 | 正常结束 |
| DONE_WITH_CONCERNS | 修复完成，但无法完全验证 | 间歇性 bug、需要 staging 验证 |
| BLOCKED | 调查后根因仍不明确，已升级 | 3-strike 后选 B |

---

## Capture Learnings（捕获学习）

> **原文**：
> ```
> ## Capture Learnings
>
> If you discovered a non-obvious pattern, pitfall, or architectural insight
> during this session, log it for future sessions:
>
> gstack-learnings-log '{"skill":"investigate","type":"TYPE","key":"SHORT_KEY",
>   "insight":"DESCRIPTION","confidence":N,"source":"SOURCE",
>   "files":["path/to/relevant/file"]}'
>
> Types: pattern, pitfall, preference, architecture, tool, operational
> Confidence: 1-10.
> files: Include specific file paths this learning references.
> Only log genuine discoveries.
> ```

**中文**：如果本次会话发现了非显而易见的模式、坑或架构洞察，记录供未来会话使用。

**Learning 类型**：

| 类型 | 含义 | 示例 |
|------|------|------|
| `pattern` | 可复用的方法 | "这个项目的 API 错误总是包在 data.error 里" |
| `pitfall` | 不该做的事 | "不要直接 mock Redis 连接——用 fakeredis" |
| `preference` | 用户明确表达的偏好 | "用户不喜欢修复涉及超过 3 个文件" |
| `architecture` | 结构性决策 | "auth 模块是单例，多线程下注意状态" |
| `tool` | 库/框架洞察 | "这个版本的 ORM 的 N+1 问题需要手动 eager load" |
| `operational` | 项目环境/CLI/工作流知识 | "需要先 source .env.local 才能跑测试" |

**置信度标准**：

| 置信度 | 来源 |
|--------|------|
| 8-9 | 在代码里亲自验证过的模式 |
| 4-5 | 推断，不确定 |
| 10 | 用户明确表达的偏好 |

> **设计原理**：`files` 字段启用了"过期检测"——如果引用的文件后来被删除，这条 learning 可以被标记为可能失效。这解决了知识库腐化问题：代码改了，但积累的经验还在引用旧路径。

---

## Important Rules（重要规则汇总）

> **原文**：
> ```
> ## Important Rules
>
> - 3+ failed fix attempts → STOP and question the architecture.
> - Never apply a fix you cannot verify.
> - Never say "this should fix it." Verify and prove it. Run the tests.
> - If fix touches >5 files → AskUserQuestion about blast radius.
> - Completion status:
>   - DONE — root cause found, fix applied, regression test written, all tests pass
>   - DONE_WITH_CONCERNS — fixed but cannot fully verify
>   - BLOCKED — root cause unclear after investigation, escalated
> ```

**中文**：

1. **3+ 次修复失败 → 停止，质疑架构**。不是失败的假设——是错误的架构层。
2. **永远不要应用无法验证的修复**。
3. **永远不说"这应该能修"**。验证并证明。跑测试。
4. **修复触及 >5 文件 → AskUserQuestion** 讨论爆炸半径。
5. **完成状态三态**：DONE / DONE_WITH_CONCERNS / BLOCKED。

---

## Telemetry & Operational Self-Improvement（遥测与自我改进）

**遥测**（Preamble 结尾运行）：

技能完成后，记录遥测事件：技能名、持续时长（秒）、结果（success/error/abort）、session ID。本地始终写入 `~/.gstack/analytics/skill-usage.jsonl`，远程遥测需用户明确开启。

**Operational Self-Improvement**（Preamble 末尾）：

> **原文**：
> ```
> Before completing, reflect on this session:
> - Did any commands fail unexpectedly?
> - Did you take a wrong approach and have to backtrack?
> - Did you discover a project-specific quirk?
> - Did something take longer than expected?
>
> A good test: would knowing this save 5+ minutes in a future session?
> ```

**中文**：完成前反思本次会话：命令意外失败了吗？走了弯路吗？发现项目特有的怪癖了吗？如果"提前知道这件事能节省 5 分钟以上"，就记录下来。

---

## 完整流程总图

```
用户报告 bug / 错误 / "昨天还好好的"
                 │
                 ▼
         ╔═══════════════╗
         ║  IRON LAW      ║
         ║  没有根因调查  ║
         ║  不准修复      ║
         ╚═══════════════╝
                 │
                 ▼
    ┌─────────────────────────────────┐
    │  Preamble 初始化                 │
    │  · 加载 learnings               │
    │  · 读取分支/repo 环境           │
    │  · 写入 timeline 日志           │
    └──────────────┬──────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────┐
    │  Phase 1: Root Cause Investigation │
    │  ① 收集症状（每次只问一个问题）  │
    │  ② 读代码（从症状往回追溯）      │
    │  ③ git log（是否是回归？）       │
    │  ④ 复现（能确定性触发吗？）      │
    │  输出：根因假设                  │
    └──────────────┬──────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────┐
    │  Scope Lock（范围锁定）          │
    │  找最窄目录 → write freeze-dir   │
    │  hooks 在每次 Edit/Write 前检查  │
    └──────────────┬──────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────┐
    │  Phase 2: Pattern Analysis       │
    │  对照 6 种已知模式：             │
    │  竞态/空值/状态损坏/集成失败     │
    │  /配置漂移/缓存陈旧              │
    │  + git log 同区域历史            │
    │  + WebSearch（脱敏后）           │
    └──────────────┬──────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────┐
    │  Phase 3: Hypothesis Testing     │
    │  加临时日志/断言验证假设         │
    │  运行复现                        │
    │  ├─ 匹配 → 进入 Phase 4         │
    │  └─ 不匹配 → 回 Phase 1        │
    │       第 3 次失败？→ STOP       │
    │       A)新假设 B)升级 C)等日志  │
    └──────────────┬──────────────────┘
                   │ 根因确认
                   ▼
    ┌─────────────────────────────────┐
    │  Phase 4: Implementation         │
    │  · 修根因，不是症状              │
    │  · 最小 diff                    │
    │  · 回归测试（先 FAIL，再 PASS） │
    │  · 全测试套件，粘贴输出          │
    │  · >5 文件 → AskUserQuestion   │
    └──────────────┬──────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────┐
    │  Phase 5: Verification & Report  │
    │  新鲜验证（必须做）             │
    │  DEBUG REPORT:                  │
    │  Symptom / Root cause / Fix     │
    │  Evidence / Regression test     │
    │  Related / Status               │
    └──────────────┬──────────────────┘
                   │
                   ▼
    ┌─────────────────────────────────┐
    │  Capture Learnings               │
    │  非显而易见的发现 → 记录         │
    │  类型/置信度/文件路径            │
    └──────────────┬──────────────────┘
                   │
                   ▼
         遥测日志写入 + 完成
```

---

## 设计核心思路汇总表

| 设计决策 | 具体机制 | 解决的问题 |
|---------|---------|---------|
| **Iron Law（铁律）** | 全大写 "NO FIXES WITHOUT ROOT CAUSE"，整个技能的前提 | 阻止 AI 修症状，防止打地鼠式调试 |
| **hooks（钩子机制）** | Frontmatter 里 PreToolUse 拦截每次 Edit/Write | 物理阻止改范围外文件，不依赖 AI 自律 |
| **Scope Lock（范围锁）** | 形成假设后锁最窄目录，写入 freeze-dir.txt | 调试时防止"顺手改了不相关代码" |
| **3-strike rule（三次法则）** | 3 次假设失败自动 STOP，给出三选项 | 防止 AI 无限猜测，识别架构问题 |
| **Pattern Analysis 表** | 6 种已知 bug 模式，结构化排查 | 把有经验工程师的模式识别显式化 |
| **回归测试先 FAIL** | 要求测试在无修复时必须失败 | 防止无意义的测试（写了但不测真实问题） |
| **>5 文件阈值** | 超过 5 文件强制 AskUserQuestion | 识别潜在架构问题或 AI 走偏 |
| **DEBUG REPORT 格式** | 强制结构化输出，每字段有具体要求 | 提供可追溯的证据链，不接受含糊结论 |
| **Capture Learnings** | 调试结束后记录发现，带文件路径做过期检测 | 知识跨会话积累，避免重复踩同一个坑 |
| **脱敏 WebSearch** | Phase 2/3 搜索前必须去掉内部数据 | 防止敏感信息泄漏到搜索引擎 |
| **Preamble tier 2** | 比 plan 类技能低一级（tier 3/4），减少引导式交互 | 调试需要快速行动，不适合过多前置问答 |
| **自我改进反思** | 完成前反思"这次发现的知识能否节省未来 5 分钟" | 持续提升 AI 在特定项目的有效性 |
