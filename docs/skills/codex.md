# `/codex` 技能逐段中英对照注解

> 对应源文件：[`codex/SKILL.md`](https://github.com/garrytan/gstack/blob/main/codex/SKILL.md)（1076 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: codex
preamble-tier: 3
version: 1.0.0
description: |
  OpenAI Codex CLI wrapper — three modes. Code review: independent diff review via
  codex review with pass/fail gate. Challenge: adversarial mode that tries to break
  your code. Consult: ask codex anything with session continuity for follow-ups.
  The "200 IQ autistic developer" second opinion.
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

- **name**: 技能名称。用户输入 `/codex` 触发。也接受语音别名 "code x"、"get another opinion"。
- **preamble-tier: 3**: 标准 tier-3 前置脚本。
- **description**: OpenAI Codex CLI 包装器——三种模式。代码审查：通过 `codex review` 做独立 diff 审查，有 pass/fail 门控。挑战：对抗模式，尝试破坏你的代码。咨询：向 Codex 询问任何问题，支持会话连续性。它是"200 IQ 自闭症开发者"式的第二意见。
- **allowed-tools**: 没有 **Edit**——这个技能是只读的，Codex 本身也运行在只读沙箱模式下。

> **设计原理：为什么没有 Edit？**
> `/codex` 的价值在于它是一个独立的第二意见——它只观察、分析、报告，不修改任何文件。连 Codex 的沙箱也是 `-s read-only` 模式。如果 Codex 能改文件，就变成了"另一个 AI 在帮我写代码"，而不是"独立的外部审查员"。

---

## "200 IQ autistic developer" 是什么意思？

> **原文**：
> ```
> Codex is the "200 IQ autistic developer" — direct, terse, technically precise,
> challenges assumptions, catches things you might miss. Present its output faithfully,
> not summarized.
> ```

**中文**：Codex 是"200 IQ 自闭症开发者"——直接、简练、技术精准，挑战假设，捕捉你可能遗漏的东西。如实呈现它的输出，不要概括。

> **设计原理：这个比喻在说什么？**
> 这不是在描述自闭症——而是在描述一种思维风格：没有社交滤波，没有"给你面子"的包装，只有技术事实和逻辑。"200 IQ"表示推理能力强，但沟通方式直接到近乎冷漠。这种风格和 Claude（倾向于体贴、平衡、有建设性）形成对比。两种视角的碰撞才能暴露盲点。
>
> "不要概括"这条规则的背后：如果 Claude 把 Codex 的输出"翻译成更友好的语言"，就失去了独立第二意见的价值——你看到的只是 Claude 对 Codex 的解读，而不是 Codex 本身说了什么。

---

## {{PREAMBLE}} 展开区

Preamble 部分是标准的 gstack tier-3 前置脚本（与 autoplan、plan-eng-review 等相同），包含：版本检查、会话管理、Boil the Lake 原则介绍、遥测询问、CLAUDE.md 路由注入、Vendoring 检测、Spawned Session 处理。

此处不逐行解读——参见 [plan-eng-review 注解的 Preamble 章节](./plan-eng-review.md)。

---

## Step 0：检查 codex 二进制

> **原文**：
> ```
> ## Step 0: Check codex binary
>
> CODEX_BIN=$(which codex 2>/dev/null || echo "")
> [ -z "$CODEX_BIN" ] && echo "NOT_FOUND" || echo "FOUND: $CODEX_BIN"
>
> If NOT_FOUND: stop and tell the user:
> "Codex CLI not found. Install it: npm install -g @openai/codex"
> ```

**中文**：第一步是检查 `codex` 命令是否存在。如果找不到，直接停止并给出安装命令——不尝试降级、不继续执行，因为后续所有步骤都依赖这个二进制。

---

## Step 1：模式检测

> **原文**：
> ```
> ## Step 1: Detect mode
>
> 1. /codex review — Review mode (Step 2A)
> 2. /codex challenge — Challenge mode (Step 2B)
> 3. /codex with no arguments — Auto-detect:
>    - Check for a diff → if exists → ask Review or Challenge or Something else
>    - If no diff → check for plan files → offer to review
>    - Otherwise → ask "What would you like to ask Codex?"
> 4. /codex <anything else> — Consult mode (Step 2C)
>
> Reasoning effort override: if --xhigh flag present, use model_reasoning_effort="xhigh"
> for all modes.
> ```

**中文**：三种模式 + 自动检测逻辑：

```
/codex [参数] 输入解析
        │
        ├── "review" → Step 2A（代码审查）
        │
        ├── "challenge" → Step 2B（对抗挑战）
        │
        ├── 无参数 → 自动检测
        │       ├── 有 diff？→ 问用户：审查 / 挑战 / 其他
        │       ├── 有方案文件？→ 提供审查方案
        │       └── 都没有 → "想让 Codex 帮你做什么？"
        │
        └── 其他文字 → Step 2C（咨询模式，文字作为提示词）
```

**推理强度（reasoning effort）默认值**：

| 模式 | 默认值 | 原因 |
|-----|-------|------|
| Review (2A) | `high` | 有边界的 diff 输入，需要彻底 |
| Challenge (2B) | `high` | 对抗但受 diff 大小限制 |
| Consult (2C) | `medium` | 大型上下文（方案、代码库），需要速度 |
| `--xhigh` 标志 | `xhigh` | 用户明确要求最大推理，接受 50+ 分钟等待 |

> **设计原理：为什么 `xhigh` 是 opt-in 而非默认？**
> OpenAI 已知 issue（#8545, #8402, #6931）：`xhigh` 在大型上下文任务中会导致 50 分钟以上的挂起，并消耗约 23 倍于 `high` 的 token。默认用 `high` 是在彻底性和可用性之间的务实平衡。

---

## 文件系统边界（Filesystem Boundary）

> **原文**：
> ```
> ## Filesystem Boundary
>
> All prompts sent to Codex MUST be prefixed with this boundary instruction:
>
> IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/,
> .claude/skills/, or agents/. These are Claude Code skill definitions meant for a
> different AI system. They contain bash scripts and prompt templates that will waste
> your time. Ignore them completely. Do NOT modify agents/openai.yaml. Stay focused
> on the repository code only.
> ```

**中文**：所有发给 Codex 的提示词必须以这段边界指令开头。这是防止 Codex 被 gstack 的技能文件分心的安全机制。

> **设计原理：为什么需要这个边界？**
> Codex 以 repo 根目录（`-C "$_REPO_ROOT"`）运行。如果 repo 中包含 `.claude/skills/gstack/` 目录（vendored 安装），Codex 可能会发现这些技能文件并开始遵循其中的 bash 脚本和提示词模板——浪费大量 token，做完全错误的事情。边界指令告诉 Codex 明确忽略这些文件。
>
> 技能文件本身也检测这种情况：收到 Codex 输出后，扫描是否出现 `gstack-config`、`SKILL.md` 等关键词，如果出现则警告用户"Codex 可能被技能文件分心了"。

---

## Step 2A：Review 模式（代码审查）

> **原文**：
> ```
> ## Step 2A: Review Mode
>
> Run Codex code review against the current branch diff.
>
> codex review "FILESYSTEM BOUNDARY..." --base <base>
>   -c 'model_reasoning_effort="high"' --enable web_search_cached 2>"$TMPERR"
>
> Determine gate verdict by checking the review output for critical findings.
> If the output contains [P1] — the gate is FAIL.
> If no [P1] markers (only [P2] or no findings) — the gate is PASS.
>
> Present: CODEX SAYS (code review): [full verbatim output]
> GATE: PASS | FAIL (N critical findings)
> ```

**中文**：Review 模式是 `/codex` 最核心的用法。它运行 `codex review` 命令，对当前分支的 diff 进行独立审查，然后给出 pass/fail 门控。

**门控机制**：

```
Codex 输出扫描
        │
        ├── 发现 [P1] 标记 → GATE: FAIL（N 个严重问题）
        │       └── 不是建议——是要求
        │
        └── 只有 [P2] 或无标记 → GATE: PASS
```

**跨模型对比（Cross-model comparison）**：如果本次会话中之前已经运行过 `/review`（Claude 自己的代码审查），自动对比两套发现：

```
CROSS-MODEL ANALYSIS:
  Both found: [Claude 和 Codex 都发现的问题]
  Only Codex found: [Codex 独有发现]
  Only Claude found: [Claude 独有发现]
  Agreement rate: X% (N/M total unique findings overlap)
```

> **设计原理：为什么门控是 PASS/FAIL 而不是"建议"？**
> 这是刻意的设计。如果 Codex 的审查结果只是"建议"，很容易被忽视。`[P1]` = 严重问题 = 门控失败，强迫开发者在发布前处理。这和 lint 错误阻止 CI 通过是同一个逻辑——不是礼貌的请求，而是硬性要求。

**持久化审查结果**：

```bash
gstack-review-log '{"skill":"codex-review","gate":"pass/fail","findings":N,...}'
```

这让 `/ship` 的评审仪表板知道 Codex 审查已完成。

---

## Step 2B：Challenge 模式（对抗挑战）

> **原文**：
> ```
> ## Step 2B: Challenge (Adversarial) Mode
>
> Codex tries to break your code — finding edge cases, race conditions, security holes,
> and failure modes that a normal review would miss.
>
> Default prompt: "...Your job is to find ways this code will fail in production.
> Think like an attacker and a chaos engineer. Find edge cases, race conditions,
> security holes, resource leaks, failure modes, and silent data corruption paths.
> Be adversarial. Be thorough. No compliments — just the problems."
>
> With focus (e.g., "security"): Focus specifically on SECURITY.
>   Think about injection vectors, auth bypasses, privilege escalation...
> ```

**中文**：挑战模式不是"找 bug"——是"我要让这段代码在生产环境崩溃"的思维方式。Codex 扮演攻击者和混沌工程师的双重角色。

挑战模式使用 `codex exec` + JSONL 输出，能捕获 Codex 的推理轨迹（`[codex thinking]` 行）和工具调用（`[codex ran]` 行），让用户看到 Codex 在想什么、做了什么。

**支持的焦点范围**（用户可指定）：

| 命令 | 焦点 |
|-----|------|
| `/codex challenge` | 通用对抗（边界情况、竞争条件、资源泄漏） |
| `/codex challenge security` | 注入、认证绕过、权限提升、数据暴露 |
| `/codex challenge performance` | N+1 查询、内存泄漏、慢路径 |
| `/codex challenge --xhigh` | 最大推理强度 |

> **设计原理：为什么要暴露推理轨迹（`[codex thinking]`）？**
> 看到 Codex 的推理过程有两个好处：(1) 用户可以判断 Codex 是否理解了代码（还是在猜测），(2) 推理轨迹本身有时比最终结论更有价值——一个被 Codex 探索但最终放弃的攻击路径可能正是你需要加固的地方。

---

## Step 2C：Consult 模式（咨询）

> **原文**：
> ```
> ## Step 2C: Consult Mode
>
> Ask Codex anything about the codebase. Supports session continuity for follow-ups.
>
> Check for existing session: cat .context/codex-session-id 2>/dev/null
> If a session file exists, offer: Continue / Start fresh
>
> Plan review auto-detection: embed plan content directly — don't reference path.
> Codex runs sandboxed to the repo root and cannot access ~/.claude/plans/.
>
> For non-plan prompts: prepend persona prompt —
> "You are a brutally honest technical reviewer. No compliments. Just the problems."
> ```

**中文**：咨询模式是自由形式的问答，支持会话连续性（多轮对话）。

**关键设计细节——嵌入内容而非引用路径**：

> **原文**：
> ```
> IMPORTANT — embed content, don't reference path: Codex runs sandboxed to the repo
> root (-C) and cannot access ~/.claude/plans/ or any files outside the repo. You MUST
> read the plan file yourself and embed its FULL CONTENT in the prompt below.
> ```

Codex 沙箱只能访问 repo 根目录。如果你告诉 Codex"请读这个文件路径"，它会浪费 10+ 个工具调用去搜索，然后失败。正确做法：Claude 自己读文件，把全文嵌入提示词。

**会话连续性**：

```
会话 ID 管理
        │
        ├── 首次咨询：codex exec → 捕获 SESSION_ID（thread.started 事件）
        │   └── 保存到 .context/codex-session-id
        │
        └── 后续咨询：
            ├── 检测到会话文件 → AskUserQuestion: 继续 / 新开
            └── 选择继续：codex exec resume <session-id> "..."
```

> **设计原理：为什么需要会话连续性？**
> 代码审查往往不是一次性的对话——"好，你找到了这个安全漏洞，那如果我这样修会不会引入新问题？"这种追问需要 Codex 记住之前的上下文。`.context/codex-session-id` 让这个对话可以跨多次 `/codex` 调用延续。

---

## Model & Reasoning（模型与推理强度）

> **原文**：
> ```
> ## Model & Reasoning
>
> No model is hardcoded — codex uses whatever its current default is (the frontier
> agentic coding model). This means as OpenAI ships newer models, /codex automatically
> uses them.
>
> xhigh uses ~23x more tokens than high and causes 50+ minute hangs on large context
> tasks (OpenAI issues #8545, #8402, #6931). Users can override with --xhigh flag
> when they want maximum reasoning and are willing to wait.
>
> Web search: All codex commands use --enable web_search_cached so Codex can look up
> docs and APIs during review.
> ```

**中文**：模型不硬编码——随 OpenAI 默认前沿模型自动更新。`--enable web_search_cached` 让 Codex 能查文档和 API，使用 OpenAI 的缓存索引（快速、无额外成本）。

推理强度权衡：

| 级别 | Token 倍数 | 适用场景 |
|------|-----------|---------|
| medium | 1x | 大型上下文咨询，需要速度 |
| high | ~5x | 代码审查和对抗挑战（默认） |
| xhigh | ~23x | 用户明确 opt-in，接受长时等待 |

---

## Error Handling（错误处理）

> **原文**：
> ```
> ## Error Handling
>
> - Binary not found: Detected in Step 0. Stop with install instructions.
> - Auth error: "Codex authentication failed. Run codex login in your terminal."
> - Timeout: "Codex timed out after 5 minutes."
> - Empty response: "Codex returned no response. Check stderr for errors."
> - Session resume failure: Delete the session file and start fresh.
> ```

**中文**：所有错误都给出明确的下一步操作，而不是笼统的"出错了"：

| 错误类型 | 处理方式 |
|---------|---------|
| 二进制不存在 | 停止 + 给出安装命令 |
| 认证失败 | 提示运行 `codex login` |
| 超时（5 分钟） | 告知用户 diff 可能太大或 API 慢 |
| 空响应 | 提示检查 stderr |
| 会话恢复失败 | 删除会话文件，重新开始 |

---

## 重要规则

> **原文**：
> ```
> ## Important Rules
>
> - Never modify files. This skill is read-only. Codex runs in read-only sandbox mode.
> - Present output verbatim. Do not truncate, summarize, or editorialize Codex's output
>   before showing it.
> - Add synthesis after, not instead of.
> - 5-minute timeout on all Bash calls to codex.
> - No double-reviewing. If the user already ran /review, Codex provides a second
>   independent opinion.
> - Detect skill-file rabbit holes: scan Codex output for gstack-config, SKILL.md,
>   skills/gstack. If found, warn the user.
> ```

**中文**：

- **永远不修改文件**：`/codex` 是只读的。Codex 的沙箱是 `-s read-only`。
- **如实呈现输出**：不截断、不概括、不加滤波。任何 Claude 的解读都在完整输出**之后**，而不是**代替**。
- **不重复审查**：如果 `/review` 已经运行，Codex 提供第二意见，不是重新运行 Claude 的审查。
- **技能文件兔子洞检测**：如果 Codex 输出中出现 `gstack-config`、`SKILL.md`、`skills/gstack`，说明 Codex 被技能文件分心了，附上警告。

> **设计原理：为什么"如实呈现"这么重要？**
> 这条规则保护了 `/codex` 的核心价值：独立的第二意见。如果 Claude 先过滤 Codex 的输出，用户看到的就不再是 Codex 说了什么，而是 Claude 认为 Codex 应该说了什么。两个 AI 都礼貌地同意彼此，毫无价值。"如实呈现"保证了这两个模型真的是独立声音。

---

## /codex 在 /autoplan 中的角色

`/codex` 作为独立技能运行时，提供外部第二意见。但在 `/autoplan` 的流水线中，它是每个评审阶段的双声部之一：

```
/autoplan 中的 Codex 使用
        │
        ├── Phase 1（CEO）: codex exec 扮演"CEO 战略顾问"角色
        │       └── 挑战：这是正确的问题吗？范围合理吗？
        │
        ├── Phase 2（Design，条件性）: codex exec 扮演"高级产品设计师"角色
        │       └── 挑战：信息层级正确吗？缺少哪些状态？
        │
        ├── Phase 3（Eng）: codex exec 扮演"高级工程师"角色
        │       └── 挑战：架构合理吗？测试覆盖充分吗？
        │
        └── Phase 3.5（DX，条件性）: codex exec 扮演"从未见过这个产品的开发者"
                └── 挑战：从 0 到 hello world 要多少步？
```

所有 `/autoplan` 中的 Codex 调用都加了"文件系统边界"前缀，防止 Codex 读 gstack 的技能文件。

---

## 整体流程总结图

```
/codex 完整决策流程
═══════════════════════════════════════════════════════════════════

用户输入 /codex [参数]
        │
        ▼
[Step 0: 检查 codex 二进制]
        │
        ├── NOT_FOUND → 停止 + 给出安装命令
        └── FOUND → 继续
                │
                ▼
[Step 1: 模式检测]
        │
        ├── "review" ───────────────→ [Step 2A: Review 模式]
        │                                    │
        │                            codex review --base <base>
        │                            reasoning: high
        │                            5 分钟超时
        │                                    │
        │                            扫描 [P1] 标记
        │                                    │
        │                            ┌───────────────────┐
        │                            │ GATE: PASS / FAIL │
        │                            └───────────────────┘
        │                                    │
        │                            （如有 /review 记录）
        │                            跨模型对比分析
        │                                    │
        │                            写入 gstack-review-log
        │
        ├── "challenge" ──────────→ [Step 2B: Challenge 模式]
        │                                    │
        │                            codex exec（adversarial prompt）
        │                            reasoning: high，read-only 沙箱
        │                            JSONL 输出 → 提取推理轨迹
        │                                    │
        │                            展示 [codex thinking] + 最终输出
        │
        ├── 无参数 → 自动检测
        │       │
        │       ├── 有 diff → AskUserQuestion: 审查/挑战/其他
        │       ├── 有方案文件 → 提供方案审查
        │       └── 都无 → "想让 Codex 做什么？"
        │
        └── 其他文字 ───────────→ [Step 2C: Consult 模式]
                                         │
                                 检查 .context/codex-session-id
                                         │
                                 ├── 有会话 → 继续或新开
                                 └── 无会话 → 新建
                                         │
                                 嵌入方案内容（而非引用路径）
                                 prepend 文件系统边界 + 角色设定
                                         │
                                 codex exec，reasoning: medium
                                 JSONL 输出 → 捕获 SESSION_ID
                                         │
                                 保存 SESSION_ID → .context/codex-session-id
                                         │
                                 展示完整输出（如实，不截断）
                                         │
                                 Claude 解读（在输出之后）
```

---

## 设计核心思路汇总表

| 设计决策 | 具体机制 | 背后原因 |
|---------|---------|---------|
| 三种模式（Review / Challenge / Consult） | Step 1 解析输入决定模式 | 覆盖不同的第二意见需求 |
| Review 模式 pass/fail 门控 | 扫描 [P1] 标记 | 不是建议，是要求——强制处理严重问题 |
| "如实呈现"规则 | 不截断、不概括 Codex 输出 | 保护独立第二意见的价值 |
| 文件系统边界指令 | 所有提示词强制前缀 | 防止 Codex 被 gstack 技能文件分心 |
| 沙箱 read-only | `-s read-only` 标志 | 确保 /codex 真正只读 |
| 嵌入内容而非路径 | Claude 读文件，把全文放入提示词 | Codex 沙箱无法访问 ~/.claude/plans/ |
| 推理强度按模式区分 | high（审查/挑战）/ medium（咨询） | 彻底性与速度的务实平衡 |
| --xhigh 为 opt-in | 默认不用，需显式标志 | xhigh 导致 50+ 分钟挂起 |
| 会话连续性（Consult） | SESSION_ID 保存到 .context/ | 多轮追问不丢上下文 |
| 跨模型对比分析 | /review 和 /codex review 对比 | 两个模型都找到的问题是高置信度信号 |
| 技能文件兔子洞检测 | 扫描输出中的 gstack 关键词 | 自动检测 Codex 是否被分心 |
| 不硬编码模型 | 跟随 codex CLI 默认 | 随 OpenAI 升级自动使用更新的模型 |
