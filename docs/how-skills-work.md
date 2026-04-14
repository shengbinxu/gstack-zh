# 技能系统深度解析

> 对应源文件：[`scripts/gen-skill-docs.ts`](https://github.com/garrytan/gstack/blob/main/scripts/gen-skill-docs.ts) · [`scripts/resolvers/`](https://github.com/garrytan/gstack/tree/main/scripts/resolvers)
> 本文解读 gstack 的技能模板系统：从 `.tmpl` 源文件到 Claude 执行的完整管线。
> 重点：理解技能是什么、怎么写、怎么编译、各模板变量的作用。

---

## 技能的本质

gstack 的"技能"（Skill）本质是一份**给 Claude 的 prompt**，保存在 `SKILL.md` 文件中。

当用户执行 `/plan-eng-review` 时，Claude Code 读取对应的 `SKILL.md`，然后**把整个文件内容当作指令**来执行。技能不是程序——没有执行引擎，只有 Claude 的理解和遵从。

```
用户输入 /plan-eng-review
         ↓
Claude Code 找到 plan-eng-review/SKILL.md
         ↓
Claude 读取文件内容（~2000行 prompt）
         ↓
Claude 按照 prompt 中的指令一步一步执行
```

**关键理解**：技能文件里写的每一条规则，都是在训练 Claude 在这个任务中的行为模式。

---

## 模板编译管线

技能文件有两个版本：

| 文件 | 作用 | 能否手动编辑 |
|------|------|-------------|
| `SKILL.md.tmpl` | 源文件，包含占位符 | **是**，这是唯一应该编辑的地方 |
| `SKILL.md` | 生成文件，最终发给 Claude | **否**，会被覆盖 |

编译命令：
```bash
bun run gen:skill-docs   # 重新生成所有 SKILL.md
bun run build            # 等价（包含 gen:skill-docs）
bun run dev:skill        # 监听模式，文件改动时自动重新生成
```

编译器源码：`scripts/gen-skill-docs.ts`

---

## 编译过程详解

```
scripts/gen-skill-docs.ts
         │
         ├── 1. 读取 SKILL.md.tmpl
         ├── 2. 解析 YAML frontmatter（name, preamble-tier, benefits-from 等）
         ├── 3. 用正则找到所有 {{PLACEHOLDER}}
         ├── 4. 在 RESOLVERS 注册表中查找对应 resolver 函数
         ├── 5. 调用 resolver(ctx)，ctx 包含：
         │       { skillName, host, paths, benefitsFrom, preambleTier }
         ├── 6. 替换占位符
         ├── 7. 验证所有占位符都已解析（否则报错）
         └── 8. 写入 SKILL.md
```

`scripts/resolvers/index.ts` 是 resolver 注册表，每个 `{{VAR}}` 对应一个函数。

---

## 9个模板变量详解

### `{{PREAMBLE}}` — 运行时初始化

**Resolver**：`scripts/resolvers/preamble.ts`

**注入时机**：每次技能启动时执行的 bash 代码块 + 一次性用户引导

**包含内容**：

```
1. Bash 初始化块
   ├── 检查 gstack 更新（throttled，每小时最多一次）
   ├── 创建 session 追踪文件（~/.gstack/sessions/）
   ├── 读取用户配置（proactive、telemetry、skill_prefix、routing）
   ├── 统计活跃会话数和历史 learnings 数
   ├── 检测是否在 Orchestrator 子会话中运行（如 OpenClaw 派生）
   └── 检测废弃的 vendored 安装方式

2. 一次性用户引导（每台机器只显示一次）
   ├── "Boil the Lake" 完整性原则介绍
   ├── 遥测许可请求（community/anonymous/off）
   ├── Proactive 行为询问（是否自动建议相关技能）
   └── 路由规则注入建议（写入 CLAUDE.md）

3. 格式规范注入
   ├── AskUserQuestion 标准格式
   ├── Completeness Principle（AI辅助下完整方案成本极低）
   └── Repo 所有权规则（越界问题如何处理）
```

**设计意图**：每个技能都有标准化的启动行为，无需重复编写。`preamble-tier` 控制注入哪些层级（1=最简，4=完整）。详见下方 [Frontmatter 字段说明](#frontmatter-字段说明) 中的分级表格。

---

### `{{BENEFITS_FROM}}` — 前置技能建议

**Resolver**：`scripts/resolvers/review.ts` → `generateBenefitsFrom()`

**触发条件**：frontmatter 中有 `benefits-from: [skill-name]` 字段

**以 plan-eng-review 为例**（`benefits-from: [office-hours]`）：

```
if 没有找到设计文档:
    AskUserQuestion: "要先运行 /office-hours 明确需求吗？"
    if 用户选择 yes:
        内联执行 /office-hours
        重新检查设计文档
    if 用户选择 no:
        继续进行工程评审
```

**设计意图**：技能之间的依赖关系通过 frontmatter 声明，而不是硬编码在 prompt 里。

---

### `{{LEARNINGS_SEARCH}}` — 历史经验检索

**Resolver**：`scripts/resolvers/learnings.ts`

**作用**：在评审开始前，检索之前会话积累的经验（learnings），避免重复犯同类错误。

**执行流程**：

```bash
gstack-learnings-search --limit 10 [--cross-project]
# 返回按相关性排序的历史 learnings，附置信度分数
```

**引用格式**：
```
Prior learning applied: [key] (confidence 8/10, from 2026-03-15)
```

**跨项目模式**：用户可以选择是否搜索其他项目的 learnings（opt-in）。

---

### `{{TEST_COVERAGE_AUDIT_PLAN}}` — 测试覆盖审计

**Resolver**：`scripts/resolvers/testing.ts`

**作用**：为计划阶段生成测试覆盖分析（不是代码实现阶段）。

**核心输出：ASCII 覆盖图**

```
代码路径覆盖图示例：
┌─────────────────────────────────────────────┐
│  Feature: 用户登录                           │
├─────────────────────────────────────────────┤
│  POST /login                                 │
│  ├── 正常路径（账号密码正确）      ★★★      │
│  ├── 密码错误                      ★★       │
│  ├── 账号不存在                    ★        │
│  ├── 并发登录（竞态）              ☆ [→E2E] │
│  └── 网络超时                      ☆ [→E2E] │
│                                             │
│  覆盖率：3/5 路径 (60%)                     │
│  缺口：并发场景、超时处理需补充测试          │
└─────────────────────────────────────────────┘

★★★ = 覆盖含边界情况  ★★ = 仅快乐路径  ★ = 烟雾测试  ☆ = 未覆盖
```

**标记含义**：
- `[→E2E]`：建议补充端到端测试
- `[→EVAL]`：建议补充 LLM 评估（用于 prompt 变更）

**附加产出**：将测试计划写入 `~/.gstack/projects/{slug}/`，供 `/qa` 技能消费。

---

### `{{CONFIDENCE_CALIBRATION}}` — 置信度标定

**Resolver**：`scripts/resolvers/confidence.ts`

**作用**：为评审发现建立统一的置信度评分标准，避免 AI 过度自信或误报。

**1-10分标准**：

| 分数 | 含义 | 呈现方式 |
|------|------|----------|
| 9-10 | 读代码验证，能演示的具体 bug | 正常显示 |
| 7-8 | 高置信度模式匹配 | 正常显示 |
| 5-6 | 中等置信度，可能误报 | 附加说明后显示 |
| 3-4 | 低置信度，可疑但可能没问题 | 从主报告中压制 |
| 1-2 | 纯推测 | 只在 P0 严重性时报告 |

**发现格式**：
```
[SEVERITY] (confidence: 8/10) src/auth/login.ts:42 — 缺少超时处理
```

---

### `{{CODEX_PLAN_REVIEW}}` — 外部 AI 二审

**Resolver**：`scripts/resolvers/review.ts` → `generateCodexPlanReview()`

**作用**：邀请不同 AI 模型（Codex CLI 或 Claude 子代理）对计划做独立评审，引入"外部视角"。

**执行流程**：

```
1. 检测 Codex CLI 是否安装（which codex）
   │
   ├── 已安装 → AskUserQuestion: "要运行独立的 Codex 二审吗？"
   │   if yes → 构建评审 prompt，运行 codex exec（只读模式，5分钟超时）
   │
   └── 未安装 → 使用 Claude Agent 工具派遣独立子代理

2. 对比主评审与外部评审的发现：
   ├── 共同发现 → 强信号，重点标出
   └── 分歧 → 呈现双方观点，让用户决定

3. 外部声音规则：
   所有外部发现仅供参考（INFORMATIONAL），
   必须通过 AskUserQuestion 获得用户明确批准才能纳入计划。
```

**设计意图**：跨模型共识是强信号，但用户永远是最终决策者。

---

### `{{REVIEW_DASHBOARD}}` — 评审就绪看板

**Resolver**：`scripts/resolvers/review.ts` → `generateReviewDashboard()`

**作用**：展示所有评审类型的完成状态，帮助用户决定是否可以进入 `/ship`。

**看板示例**：

```
┌────────────────────────────────────────────────────────────┐
│ Review Readiness Dashboard                                  │
├──────────────────┬──────┬─────────────────┬────────┬───────┤
│ Review           │ Runs │ Last Run        │ Status │ Req'd │
├──────────────────┼──────┼─────────────────┼────────┼───────┤
│ Eng Review       │  2   │ 2026-04-06 14:30│ CLEAR  │ YES   │
│ CEO Review       │  1   │ 2026-04-05 10:00│ CLEAR  │ no    │
│ Design Review    │  0   │ —               │ —      │ no    │
│ Adversarial      │  1   │ 2026-04-06 14:30│ CLEAR  │ auto  │
│ Outside Voice    │  1   │ 2026-04-06 14:30│ CLEAR  │ no    │
└──────────────────┴──────┴─────────────────┴────────┴───────┘

Verdict: CLEARED — run /ship when ready
```

**裁决逻辑**：
- `CLEARED`：Eng Review 存在 + 7天内 + status=clean，或全局跳过已启用
- `NOT CLEARED`：Eng Review 缺失/过期/有未解决问题

**过期检测**：比较评审时的 commit hash 与当前 HEAD，如有大量新提交则警告评审可能过期。

---

### `{{PLAN_FILE_REVIEW_REPORT}}` — 回写计划文件

**Resolver**：`scripts/resolvers/review.ts` → `generatePlanFileReviewReport()`

**作用**：把评审结果汇总写回计划文件（plan doc）的末尾，形成持久化记录。

**写入格式**：

```markdown
## GSTACK REVIEW REPORT

| Review    | Trigger | Why           | Runs | Status | Findings      |
|-----------|---------|---------------|------|--------|---------------|
| Eng       | /autoplan | 架构锁定    | 2    | CLEAR  | 3 issues, 0 critical |
| CEO       | manual   | 产品方向确认 | 1    | CLEAR  | scope reduced |

CODEX: 2 independent findings
CROSS-MODEL: 1 consensus (auth boundary concern — HIGH signal)
Unresolved: 0
Verdict: CLEARED
```

**写入规则**：
- 搜索已有 `## GSTACK REVIEW REPORT` 节（可能在文件中间）
- 如找到 → 整节替换
- 如未找到 → 追加到文件末尾
- 始终作为文件最后一节

---

### `{{LEARNINGS_LOG}}` — 经验沉淀

**Resolver**：`scripts/resolvers/learnings.ts`

**作用**：指导 Claude 在会话结束时把非显而易见的发现记录到持久存储，供未来会话复用。

**记录格式**：

```bash
gstack-learnings-log '{
  "skill": "plan-eng-review",
  "type": "pitfall",           # pattern/pitfall/preference/architecture/tool/operational
  "key": "auth-middleware-session-storage",
  "insight": "该项目的 auth middleware 把 session token 存在内存中，重启后失效，但测试不覆盖这个场景",
  "confidence": 9,             # 1-10，观察验证=8-9，用户明确告知=10，推断=4-5
  "source": "observed",        # observed/user-stated/inferred/cross-model
  "files": ["src/middleware/auth.ts"]  # 用于过期检测
}'
```

**记录质量标准**：
- 只记录真正的新发现，不记录显而易见的东西
- 自测："这个洞察在未来会话中能节省时间吗？"

---

## Frontmatter 字段说明

每个 `.tmpl` 文件头部的 YAML：

```yaml
---
name: plan-eng-review          # 技能标识符
preamble-tier: 3               # 前导内容级别（1=最简 → 4=完整）
version: 1.0.0                 # 版本号
description: |                 # 多行描述（显示在技能列表中）
  ...
voice-triggers:                # 用户说这些词时自动建议使用此技能
  - "tech review"
  - "technical review"
benefits-from: [office-hours]  # 运行前最好先跑的技能（软依赖）
allowed-tools:                 # 允许使用的工具白名单
  - Read / Write / Grep / AskUserQuestion / Bash / WebSearch
---
```

**`preamble-tier` 的含义**：

`preamble-tier` 控制 `{{PREAMBLE}}` 注入的内容丰富程度，tier 越高越完整：

| Tier | 包含内容 | 典型技能 |
|------|---------|---------|
| **1** | 仅基础 bash 初始化，无任何交互提示 | 轻量工具类 |
| **2** | + gstack 更新检查 | 简单分析类 |
| **3** | + 一次性用户引导（遥测许可、proactive 行为、routing 规则注入） | 大多数技能（`/plan-eng-review`、`/qa` 等） |
| **4** | + session 追踪、vendored 安装弃用警告、完整 "Boil the Lake" 原则 | 关键路径技能（`/review`、`/ship`） |

**为什么要分级？** 轻量技能无需每次都运行完整的初始化流程；而 `/review`、`/ship` 是代码入库前的最后关口，出错成本最高，值得注入所有安全网。Tier 越高，启动时的上下文越完整，同时也意味着稍多的 token 消耗。

---

## 技能编写规范（来自 CLAUDE.md）

1. **用自然语言写逻辑，不用 shell 变量传递状态**
   - 错误：用 `RESULT=$(...)` 在代码块间传状态
   - 正确：告诉 Claude "记住上一步检测到的 base branch"

2. **每个 bash 块独立自洽**，因为每个块在独立 shell 中执行

3. **条件逻辑用英文数字步骤**，而非嵌套 if/else

4. **不硬编码分支名**（main/master），动态检测

5. **平台无关**：不写框架特定命令，从 CLAUDE.md 读取项目配置

---

## 技能分类

gstack 的 35 个技能分为两类：

**工作流技能**（指导 Claude 做复杂决策）：

| 类别 | 技能 |
|------|------|
| 计划评审 | `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/plan-devex-review` |
| 代码评审 | `/review`, `/cso`（安全审计） |
| 发布流程 | `/ship`, `/land-and-deploy`, `/canary` |
| QA | `/qa`, `/qa-only`, `/design-review` |
| 调试 | `/investigate` |
| 其他 | `/office-hours`, `/retro`, `/document-release`, `/codex`, `/autoplan` |

**工具技能**（直接操作工具）：

| 技能 | 功能 |
|------|------|
| `/browse` | 无头浏览器（核心工具） |
| `/open-gstack-browser` | 打开可见 Chromium 窗口 |
| `/setup-browser-cookies` | 从真实浏览器导入 cookies |
| `/freeze` / `/unfreeze` | 限制/解除文件编辑范围 |
| `/careful` / `/guard` | 安全保护模式 |
| `/checkpoint` | 保存/恢复工作状态 |
| `/learn` | 管理历史 learnings |
| `/gstack-upgrade` | 升级 gstack |
