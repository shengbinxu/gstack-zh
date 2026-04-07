# `/review` 技能逐段中英对照注解

> 对应源文件：[`review/SKILL.md`](https://github.com/garrytan/gstack/blob/main/review/SKILL.md)（1467 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: review
preamble-tier: 4
version: 1.0.0
description: |
  Pre-landing PR review. Analyzes diff against the base branch for SQL safety, LLM trust
  boundary violations, conditional side effects, and other structural issues. Use when
  asked to "review this PR", "code review", "pre-landing review", or "check my diff".
  Proactively suggest when the user is about to merge or land code changes. (gstack)
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - WebSearch
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/review` 触发。
- **preamble-tier: 4**：最高级别 Preamble，与 `/ship` 相同。包含完整的环境初始化、升级检查、session 追踪、telemetry、Boil the Lake 原则、路由注入、Vendoring 检测。
- **description**: 落地前 PR 评审。分析当前分支与基础分支的 diff，检查 SQL 安全、LLM 信任边界违规、条件副作用等结构性问题。
- **allowed-tools**: 包含 **Edit 和 Write**——这是关键区别。`/review` 采用 Fix-First 原则：发现问题直接修复，不只是报告。也包含 **Agent**，用于并行派遣专家子 Agent。

> **为什么 preamble-tier: 4 是最高级？**
> Tier 4 代表 gstack 认为这个技能足够关键，值得运行全部前置检查。`/review` 和 `/ship` 共享 Tier 4——因为它们都是代码入库前的最后关口，错误成本最高。Tier 3（/plan-eng-review）不需要 Edit，不需要 Agent，所以前置上下文轻一些。

---

## 核心定位：`/review` vs 其他评审技能

> **原文**：
> ```
> # Pre-Landing PR Review
> You are running the /review workflow. Analyze the current branch's diff against
> the base branch for structural issues that tests don't catch.
> ```

**中文**：你在运行 `/review` 工作流。分析当前分支与基础分支的 diff，检查**测试无法捕获的结构性问题**。

### 与 `/plan-eng-review` 的核心区别

| 维度 | `/review` | `/plan-eng-review` |
|------|-----------|-------------------|
| **阶段** | 代码已写好，准备 merge | 方案阶段，代码还没写 |
| **输入** | `git diff`（实际代码变更） | 设计文档（计划中的架构） |
| **输出** | 直接修复 + ASK 确认 | 交互式讨论 + 建议 |
| **是否改代码** | 是（Fix-First） | 否（只读） |
| **核心问题** | "这段代码安全吗？" | "这个设计合理吗？" |
| **preamble-tier** | 4（最高） | 3 |
| **allowed-tools 有 Edit** | 是 | 否 |
| **触发时机** | 准备 merge 时 | 开始编码前 |

> 简单说：`/plan-eng-review` 是开工前的建筑审查，`/review` 是竣工后的质检。

### 与 `/qa` 的核心区别

| 维度 | `/review` | `/qa` |
|------|-----------|-------|
| **分析方式** | 静态代码分析（看 diff） | 动态运行时测试（跑网站） |
| **什么测不到** | 运行时行为、UI 交互 | SQL 注入、竞态条件（单线程） |
| **什么测得到** | 代码结构、安全模式、架构 | 功能是否工作、UI 是否渲染 |
| **需要运行应用** | 否 | 是 |
| **使用浏览器** | 否 | 是（$B 命令） |
| **最佳执行时间** | 代码写完，部署前 | 部署后，上线前 |

> `/review` 和 `/qa` 是互补的，不是替代关系。`/ship` 会在创建 PR 之前检查这两个是否都运行过。

### 三技能组合的完整工作流

```
代码变更
    │
    ├─► /plan-eng-review  ← 方案阶段：架构合理吗？
    │        ↓
    │    开始编码
    │        ↓
    ├─► /review           ← 代码阶段：实现安全吗？
    │        ↓
    │    /ship 创建 PR
    │        ↓
    └─► /qa               ← 运行时阶段：功能正常吗？
             ↓
         /land-and-deploy
```

---

## {{PREAMBLE}} 展开区

`/review` 使用 Tier 4 Preamble，与 `/ship` 相同。Tier 4 是 preamble 的最高级别，包含：

1. **Bash 环境初始化**：版本检查、session 追踪、telemetry
2. **Boil the Lake 原则**：AI 让完整性变得廉价，不要走捷径
3. **Garry Tan 的 Voice 指引**：直接、具体、有立场
4. **AskUserQuestion 格式规范**：项目名 + 分支名 + 编号选项 + 完整度评分
5. **Context Recovery**：会话压缩后如何重建上下文
6. **Repo 模式检测**：solo vs collaborative，影响"发现问题就修"还是"先问人"
7. **ROUTING 注入**：如果用户没有 routing rules，引导注入到 CLAUDE.md
8. **Vendoring 检测**：检测 vendored gstack，引导迁移到 team mode
9. **SPAWNED_SESSION 检测**：在 orchestrator 中运行时跳过交互式提示

---

## Step 0：平台检测与基础分支确定

> **原文**：
> ```bash
> git remote get-url origin 2>/dev/null
> # 检测结果：
> # - github.com → GitHub
> # - gitlab → GitLab
> # - 否则检查 gh/glab CLI
> ```

这一步在所有实际工作之前运行，确定 `<base>` 分支，供后续所有 git 命令使用。

**基础分支确定优先级**：

```
GitHub 平台：
  1. gh pr view --json baseRefName    (已有 PR → 精确目标)
  2. gh repo view --json defaultBranchRef  (仓库默认分支)

GitLab 平台：
  1. glab mr view -F json → target_branch
  2. glab repo view -F json → default_branch

Git 原生回退（平台未知或 CLI 失败）：
  1. git symbolic-ref refs/remotes/origin/HEAD
  2. origin/main 存在 → "main"
  3. origin/master 存在 → "master"
  4. 全部失败 → 默认 "main"
```

> **设计原理**：为什么要精确检测基础分支？因为 diff 的范围完全依赖于此。如果误把 `develop` 当 `main`，可能漏掉或多报大量变更，导致整个评审失去意义。

---

## Step 1：分支检查

> **原文**：
> ```
> 1. Run git branch --show-current to get the current branch.
> 2. If on the base branch, output: "Nothing to review — you're on the base branch
>    or have no changes against it." and stop.
> 3. Run git fetch origin <base> --quiet && git diff origin/<base> --stat
>    to check if there's a diff. If no diff, output the same message and stop.
> ```

**中文**：
1. 获取当前分支名
2. 如果在基础分支上（直接在 main 开发），评审没有意义——直接结束
3. 拉取最新基础分支，检查是否有 diff；如果 diff 为空则结束

> **设计原理**：快速失败。如果没有 diff，所有后续步骤都是浪费。这两行检查避免了 AI 在空 diff 上运行昂贵的评审逻辑。

---

## Step 1.5：Scope Drift Detection（范围偏移检测）

> **原文**：
> ```
> Before reviewing code quality, check: did they build what was requested
> — nothing more, nothing less?
> ```

**中文**：在评审代码质量之前，先检查：**他们是否只构建了被要求的内容？**

这一步的核心洞察：代码写得再好，如果做了多余的事或遗漏了必要的事，都是问题。

**信息来源优先级**（按可靠性排序）：
1. `TODOS.md`——最结构化的意图记录
2. PR 描述（`gh pr view --json body`）——如果已有 PR
3. 提交信息（`git log --oneline`）——最低可靠性，但总有

**两类问题的识别**：

| 类型 | 含义 | 典型检测信号 |
|------|------|------------|
| **SCOPE CREEP**（范围蔓延） | 做了不该做的事 | 与意图无关的文件变更、未提及的新功能重构 |
| **MISSING REQUIREMENTS**（遗漏需求） | 该做的没做 | TODOS.md 中的项目在 diff 中完全没有痕迹 |

**输出格式**：
```
Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
Intent: <1行：被要求做什么>
Delivered: <1行：diff 实际做了什么>
[如果有偏移：列举每个超出范围的变更]
[如果有遗漏：列举每个未处理的需求]
```

这是**仅供参考**的信息，不阻塞评审继续进行。

> **设计原理**：为什么要在代码质量评审前先做范围检查？因为范围错误的代码，无论写得多好，都要重做或撤销。先确认"做了正确的事"，再讨论"做的方式对不对"。

---

## Plan File Discovery（计划文件发现）与完成度审计

### 计划文件搜索

> **原文**：
> ```
> 1. Conversation context (primary): Check if there is an active plan file
>    in this conversation.
> 2. Content-based search (fallback): Search common plan file locations
> 3. Validation: Read first 20 lines and verify it is relevant
> ```

**搜索路径**（按优先级）：
1. 当前会话上下文中引用的计划文件（最可靠）
2. `~/.gstack/projects/<slug>/*.md` 中与当前分支名或 repo 名匹配的文件
3. `~/.claude/plans/`、`~/.codex/plans/`、`.gstack/plans/` 中最近修改的文件

### Actionable Item Extraction（可操作项提取）

读取计划文件，提取所有可操作项目：

**提取的内容类型**：

| 类型 | 示例 |
|------|------|
| Checkbox items | `- [ ] Create UserService`、`- [x] Add migration` |
| 编号步骤 | `1. Create model`、`2. Add controller` |
| 祈使句 | "Add X to Y"、"Create a Z service" |
| 文件级规格 | "New file: path/to/file.ts" |
| 测试要求 | "Test that X"、"Add test for Y" |
| 数据模型变更 | "Add column X to table Y" |

**忽略的内容**：
- `## Context`、`## Background` 章节（背景，不是任务）
- 带 `?`、`TBD`、`TODO: decide` 的问题（待定，不是任务）
- `## GSTACK REVIEW REPORT`（评审报告本身）
- `Future:`、`Out of scope:`、`P2:`、`P3:` 明确标注为推迟的项目

### Cross-Reference Against Diff（交叉比对）

对每个提取的计划项，检查 diff 并分类：

| 状态 | 含义 | 判断标准 |
|------|------|---------|
| **DONE** | diff 中有明确证据 | 必须引用具体文件，光 touch 文件不算 |
| **PARTIAL** | 有开始但不完整 | 如：model 建了但 controller 没改 |
| **NOT DONE** | diff 中无任何痕迹 | 完全没有相关变更 |
| **CHANGED** | 用不同方式实现同一目标 | Redis queue → Sidekiq（目标达成，方式不同） |

> **CHANGED 状态的价值**：区分"没做"和"换了方式做"。Sidekiq 替代 Redis 直接使用是有意的架构决策，不是遗漏。记录这个偏差便于审计，但不算需求未完成。

**输出示例**：
```
PLAN COMPLETION AUDIT
═══════════════════════════════
Plan: ~/.gstack/projects/myapp/feature-auth-plan.md

## Implementation Items
  [DONE]      Create UserService — src/services/user_service.rb (+142 lines)
  [PARTIAL]   Add validation — model validates but missing controller checks
  [NOT DONE]  Add caching layer — no cache-related changes in diff
  [CHANGED]   "Redis queue" → implemented with Sidekiq instead

## Test Items
  [DONE]      Unit tests for UserService — test/services/user_service_test.rb
  [NOT DONE]  E2E test for signup flow

## Migration Items
  [DONE]      Create users table — db/migrate/20240315_create_users.rb

─────────────────────────────────
COMPLETION: 4/7 DONE, 1 PARTIAL, 1 NOT DONE, 1 CHANGED
─────────────────────────────────
```

**HIGH impact NOT DONE 的门禁**：触发 AskUserQuestion，选项：A) 停下来实现遗漏项  B) 继续发布 + 创建 P1 TODO  C) 有意删除了这个范围。

---

## Step 2：读取 checklist.md

> **原文**：
> ```
> Read .claude/skills/review/checklist.md.
> If the file cannot be read, STOP and report the error.
> Do not proceed without the checklist.
> ```

**中文**：读取评审清单文件。如果无法读取，**必须停止**。

checklist.md 是 `/review` 的核心知识库，它定义了：
1. 所有检查类别（CRITICAL vs INFORMATIONAL）
2. Fix-First 启发式规则（什么时候 AUTO-FIX，什么时候 ASK）
3. "DO NOT flag" 黑名单（避免误报）
4. 每个类别的具体检查模式

没有 checklist.md，评审就是随意发挥，失去系统性保障。这个 STOP 是硬性要求，不是建议。

---

## Step 2.5：Greptile 评审评论检查

> **原文**：
> ```
> Read .claude/skills/review/greptile-triage.md and follow the fetch, filter,
> classify, and escalation detection steps.
> If no PR exists, gh fails, or there are zero Greptile comments: Skip silently.
> ```

**Greptile 是什么**：一个 AI 驱动的代码评审服务，可以自动在 PR 上发表评论。

**分类与处理方式**：

| 分类 | 处理方式 |
|------|---------|
| VALID & ACTIONABLE（有效且需要行动） | 加入 Fix-First 流程，和结构化评审的发现一起处理 |
| VALID BUT ALREADY FIXED（有效但已修复） | 用 "Already Fixed" 模板自动回复，附上修复 commit SHA |
| FALSE POSITIVE（误报） | 展示原因，询问用户是否回复 |
| SUPPRESSED（已压制） | 静默跳过（已知误报，不再展示） |

**设计原理**：Greptile 集成是加法，不是必须。即使没有 PR、没有 Greptile 账号，评审也能正常工作。这是 gstack 的一贯设计原则——外部集成都是可选增强。

---

## Step 3：获取 Diff

> **原文**：
> ```bash
> git fetch origin <base> --quiet
> git diff origin/<base>
> ```

先 fetch 最新基础分支（避免因本地状态陈旧产生误报），然后获取完整 diff（包含已提交和未提交的变更）。

**为什么用 `origin/<base>` 而不是 `<base>`**：
- `git diff <base>` 用的是本地的 `<base>`，可能落后于远端
- `git diff origin/<base>` 用的是刚 fetch 的远端最新状态
- 如果有人刚往 main push 了代码，`origin/<base>` 更准确

---

## Prior Learnings（历史经验注入）

> **原文**：
> ```
> Search for relevant learnings from previous sessions.
> When a review finding matches a past learning, display:
> "Prior learning applied: [key] (confidence N/10, from [date])"
> This makes the compounding visible.
> ```

```bash
~/.claude/skills/gstack/bin/gstack-learnings-search --limit 10 2>/dev/null
```

如果配置了跨项目经验共享（`cross_project_learnings=true`），还会搜索同机器上其他项目的经验。

**可见的复利**：当系统说"Prior learning applied: billing-n-plus-one-pattern (confidence 8/10, from 2024-01-15)"，用户看到的是 gstack 正在变得更聪明——上周在 billing 模块发现的 N+1，这周自动提醒了。

---

## Step 4：Critical Pass（核心评审）——4 大维度深度解析

> **原文**：
> ```
> Apply the CRITICAL categories from the checklist against the diff:
> SQL & Data Safety, Race Conditions & Concurrency, LLM Output Trust Boundary,
> Shell Injection, Enum & Value Completeness.
> Also apply the remaining INFORMATIONAL categories.
> Enum & Value Completeness requires reading code OUTSIDE the diff.
> ```

### 4.1 SQL & Data Safety（SQL 与数据安全）

**这是最高优先级的 CRITICAL 类别。**

**核心检查：SQL 注入**

最常见的 SQL 安全问题是字符串拼接：

```ruby
# 危险：用户输入直接拼进 SQL
User.where("name = '#{params[:name]}'")

# 安全：参数化查询
User.where(name: params[:name])
User.where("name = ?", params[:name])
```

**MyBatis / MyBatis-Plus 场景（Java 项目重点）**：

```xml
<!-- 危险：${} 是字符串拼接，不是参数化 -->
<select id="findUser" resultType="User">
  SELECT * FROM users WHERE name = '${name}'
</select>

<!-- 安全：#{} 是 PreparedStatement 参数化 -->
<select id="findUser" resultType="User">
  SELECT * FROM users WHERE name = #{name}
</select>
```

> **${} vs #{} 是 MyBatis 最常见的 SQL 注入来源。** 任何在 diff 中出现 `${` 的地方都应该检查是否用于动态构建 SQL 条件。

**迁移安全（Migration Safety）**：

| 危险操作 | 原因 | 安全替代 |
|---------|------|---------|
| `DROP COLUMN` | 不可逆 | 先软删除（nullable），确认无用后再删 |
| 添加非空列无默认值 | 锁表，历史数据报错 | 先加 nullable 列，填充数据，再加约束 |
| 大表无索引 `ALTER TABLE` | 长时间锁表 | 在低峰期或用 online DDL |
| 同步迁移 + 代码部署 | 回滚困难 | 迁移先于代码，保持向后兼容 |

**事务边界**：
- 批量操作没有 `@Transactional` 可能导致部分成功
- 事务内包含网络调用（HTTP、发邮件）会持有锁太久
- 没有幂等性保证的操作重试时可能重复执行

### 4.2 Race Conditions & Concurrency（竞态条件与并发）

**为什么测试抓不住竞态？** 单元测试在单线程环境下运行，不模拟并发场景。

**最常见的竞态模式——TOCTOU（Time of Check to Time of Use）**：

```ruby
# 危险：check 和 use 之间有窗口
if user.balance >= amount
  user.update!(balance: user.balance - amount)  # 两个并发请求都通过了 check
end

# 安全：用 UPDATE ... WHERE 原子操作
User.where(id: user.id)
    .where("balance >= ?", amount)
    .update_all("balance = balance - #{amount}")
```

**状态机转换的竞态**：

```sql
-- 危险：两个请求同时把 draft 变成 published
UPDATE posts SET status = 'published' WHERE id = 1

-- 安全：只有在当前状态正确时才转换
UPDATE posts SET status = 'published' WHERE id = 1 AND status = 'draft'
-- 检查 affected_rows，如果是 0 说明已经被其他请求抢先了
```

**Java 中常见的并发问题**：
- `HashMap` 在多线程中使用（应该用 `ConcurrentHashMap`）
- `SimpleDateFormat` 不是线程安全的
- Spring 单例 Bean 中的实例变量被多线程共享
- `@Async` 方法的事务传播问题

### 4.3 LLM Output Trust Boundary（LLM 输出信任边界）

**这是 AI 时代出现的新安全类别。**

> **原文**：核心原则是：LLM 的输出永远不可信任，必须经过验证才能用于敏感操作。

**信任边界的本质**：LLM 可能被注入恶意提示（Prompt Injection），导致输出不可预期的内容。如果这个输出直接写入数据库、执行为 SQL、或传给另一个系统，后果可能是灾难性的。

**典型的危险模式**：

```python
# 危险：LLM 生成的 SQL 直接执行
sql = llm.generate(f"Write SQL for: {user_query}")
db.execute(sql)  # 提示注入可以让 LLM 生成 DROP TABLE

# 危险：LLM 生成的代码直接 eval
code = llm.generate(f"Write Python for: {user_request}")
eval(code)  # 极其危险

# 危险：LLM 输出直接写入重要字段
user.role = llm.extract_role(response)  # LLM 可能被诱导输出 "admin"
```

**安全做法**：

```python
# 1. 用 JSON Schema 验证 LLM 输出的结构
schema = {"type": "object", "properties": {"role": {"enum": ["user", "editor"]}}}
validate(llm_output, schema)

# 2. 用枚举/白名单限制可接受的值
ALLOWED_ROLES = {"user", "editor"}  # 没有 "admin"
role = llm_output.get("role")
if role not in ALLOWED_ROLES:
    raise ValueError(f"Invalid role: {role}")

# 3. 对 LLM 生成的内容进行转义或清理再存储
content = sanitize(llm_output.get("content", ""))
```

**`/review` 检查什么**：
- LLM 的输出（字符串、JSON 对象）是否经过类型检查再进入数据库
- LLM 输出中的字符串是否经过清理再渲染到 HTML
- LLM 生成的代码是否被 eval 或 exec 执行
- 用于继续调用 LLM 的提示是否包含了未清理的用户输入（链式提示注入）

### 4.4 Shell Injection（Shell 注入）

```python
# 危险：用户输入拼入 shell 命令
import subprocess
filename = request.get_json()['filename']
subprocess.run(f"cat /tmp/{filename}", shell=True)
# 攻击者传 "foo; rm -rf /" 就能执行任意命令

# 安全：使用参数列表，不用 shell=True
subprocess.run(["cat", f"/tmp/{filename}"])

# 更安全：验证文件名
import re
if not re.match(r'^[a-zA-Z0-9_-]+$', filename):
    raise ValueError("Invalid filename")
subprocess.run(["cat", f"/tmp/{filename}"])
```

**Java 场景**：

```java
// 危险
Runtime.getRuntime().exec("ls " + userInput);

// 安全
ProcessBuilder pb = new ProcessBuilder("ls", userInput);
```

### 4.5 Enum & Value Completeness（枚举值完整性）

这是最特殊的 CRITICAL 类别：**它需要读取 diff 之外的代码。**

**为什么测试抓不住枚举遗漏？** 通常只测试已知的枚举值，新添加的值在测试中根本没有用例。

**检查流程**：

```
1. 在 diff 中发现新枚举值：
   + PREMIUM = "premium"  # 新增 tier

2. 用 Grep 找所有引用同级枚举值的文件：
   grep -r "\"free\"\|\"basic\"\|\"enterprise\"" --include="*.rb"

3. 读取这些文件，检查新值是否被处理：
   case user.tier
   when "free"   then feature_limit = 10
   when "basic"  then feature_limit = 100
   # 没有 "premium"！ → 报告为 CRITICAL 遗漏
   end
```

**Java/MyBatis 场景**：

```java
// diff 新增枚举值
public enum OrderStatus {
    PENDING, PROCESSING, COMPLETED, CANCELLED, REFUNDED  // 新增 REFUNDED
}

// 需要检查所有 switch-case
switch (order.getStatus()) {
    case PENDING: ...
    case PROCESSING: ...
    case COMPLETED: ...
    case CANCELLED: ...
    // 没有 REFUNDED！→ CRITICAL 遗漏
}
```

### 4.6 INFORMATIONAL 类别（信息性问题）

这些问题不会直接导致安全漏洞，但会影响代码质量：

| 类别 | 典型问题 | 说明 |
|------|---------|------|
| **Async/Sync Mixing** | 在同步代码中调用 async 方法 | 可能导致死锁或未处理的 Future |
| **Column/Field Name Safety** | 字段名冲突、覆盖父类字段 | 特别在 ORM 映射中容易出问题 |
| **LLM Prompt Issues** | 提示词格式问题、上下文截断 | 影响 LLM 输出质量 |
| **Type Coercion** | 隐式类型转换（JS：`"1" + 1 = "11"`） | 静默产生错误结果 |
| **View/Frontend** | XSS、未转义的用户输入渲染 | 前端安全问题 |
| **Time Window Safety** | 时间相关的竞态（scheduler、TTL） | 缓存过期、任务重复执行 |
| **Completeness Gaps** | N+1 查询、未处理的异常路径 | 性能和可靠性问题 |
| **Distribution & CI/CD** | 环境变量硬编码、CI 配置问题 | 发布流程问题 |

> **N+1 查询举例**（MyBatis/Java）：
> ```java
> // N+1：先查 N 个 order，再对每个 order 各查一次 user
> List<Order> orders = orderMapper.findAll();
> for (Order order : orders) {
>     User user = userMapper.findById(order.getUserId());  // N 次额外查询
>     order.setUser(user);
> }
>
> // 解决：JOIN 或 IN 批量查询
> List<Order> orders = orderMapper.findAllWithUser();  // 一次 JOIN 查询
> ```

### 枚举值完整性——特殊处理的设计原理

```
传统评审：只看 diff 内的代码 → 只知道新增了 "premium" 枚举值
gstack /review：Grep 所有引用位置 → 发现哪个 switch-case 没处理

这是 /review 的核心差异之一：
系统性检查，而不是只看眼前的代码。
```

---

## Confidence Calibration（置信度校准）

> **原文**：
> ```
> Every finding MUST include a confidence score (1-10).
> Finding format: [SEVERITY] (confidence: N/10) file:line — description
> ```

| 分数 | 含义 | 展示规则 |
|------|------|---------|
| **9-10** | 通过读特定代码验证，可以演示具体的 bug 或漏洞 | 正常展示 |
| **7-8** | 高置信度模式匹配，极可能正确 | 正常展示 |
| **5-6** | 中等置信度，可能误报 | 加注 "Medium confidence，请核实" |
| **3-4** | 低置信度，模式可疑但可能正常 | 移到附录，不进主报告 |
| **1-2** | 推测 | 只有 P0 级别才报告 |

**发现格式示例**：
```
[P1] (confidence: 9/10) app/models/user.rb:42 — SQL injection via string interpolation in where clause
[P2] (confidence: 5/10) app/controllers/api/v1/users_controller.rb:18 — Possible N+1 query, verify with production logs
```

**校准学习机制**：如果报告了置信度 < 7 的发现，但用户确认这是真实问题，说明对这个模式的识别能力不足。系统会记录一个校准学习，未来对相同模式给出更高置信度。这是**主动的学习闭环**。

> **设计原理**：置信度分数解决了 AI 最常见的问题——过度自信地报告误报，或者因为不确定就什么都不说。有了显式的置信度分数，用户可以根据分数决定是否深入调查，而不是盲目信任所有发现。

---

## Step 4.5：Review Army——专家并行派遣

### Diff 范围检测

```bash
source <(~/.claude/skills/gstack/bin/gstack-diff-scope <base> 2>/dev/null) || true
```

这个命令输出一系列环境变量，控制专家的派遣：

| 变量 | 含义 |
|------|------|
| `SCOPE_AUTH=true` | diff 涉及认证/授权代码 |
| `SCOPE_BACKEND=true` | diff 涉及后端逻辑 |
| `SCOPE_FRONTEND=true` | diff 涉及前端代码 |
| `SCOPE_MIGRATIONS=true` | diff 涉及数据库迁移 |
| `SCOPE_API=true` | diff 涉及 API 接口定义 |

### 专家选择逻辑

```
DIFF_LINES < 50
  └─► 跳过所有专家，打印 "Small diff — specialists skipped"

DIFF_LINES >= 50
  ├─► 总是派遣（Always-on）：
  │     • Testing（测试专家）
  │     • Maintainability（可维护性专家）
  │
  └─► 条件派遣：
        • Security    ← SCOPE_AUTH=true 或 (SCOPE_BACKEND=true AND DIFF_LINES > 100)
        • Performance ← SCOPE_BACKEND=true 或 SCOPE_FRONTEND=true
        • Data Migration ← SCOPE_MIGRATIONS=true
        • API Contract   ← SCOPE_API=true
        • Design         ← SCOPE_FRONTEND=true（用 design-checklist.md）
```

### Adaptive Gating（自适应门控）

```bash
~/.claude/skills/gstack/bin/gstack-specialist-stats 2>/dev/null
```

基于历史命中率自动跳过低效专家：

- 标记为 `[GATE_CANDIDATE]`（10+ 次派遣，0 发现）→ 自动跳过
- 标记为 `[NEVER_GATE]`（Security、Data Migration）→ **永远派遣**，这是保险政策专家

> **设计原理**：Security 和 Data Migration 是永不门控的——因为它们是"保险政策"型专家。SQL 安全在 99 次评审里可能都没问题，但第 100 次可能就是数据泄露。那 99 次的"浪费"是可以接受的。

**强制标志**：用户可以通过 `--security`、`--performance`、`--all-specialists` 等标志强制包含特定专家，忽略门控。

### 并行派遣机制

> **原文**：
> ```
> For each selected specialist, launch an independent subagent via the Agent tool.
> Launch ALL selected specialists in a single message so they run in parallel.
> Each subagent has fresh context — no prior review bias.
> ```

所有被选中的专家在**同一条消息**中通过多个 Agent tool calls 启动，并行运行。每个子 Agent 有**全新的上下文**，没有主评审的偏见积累。

**每个专家子 Agent 的 Prompt 包含**：
1. 该专家的 checklist 内容（`specialists/testing.md`、`specialists/security.md` 等）
2. 技术栈上下文：`"This is a {STACK} project"`
3. 该领域的历史经验（pitfall learnings）
4. 指令：以 JSON Lines 格式输出每个发现

**发现 JSON 格式**：
```json
{
  "severity": "CRITICAL",
  "confidence": 8,
  "path": "app/models/user.rb",
  "line": 42,
  "category": "sql-safety",
  "summary": "SQL injection via string interpolation in where clause",
  "fix": "Use parameterized query: User.where('name = ?', name)",
  "fingerprint": "app/models/user.rb:42:sql-safety",
  "specialist": "security",
  "test_stub": "describe 'SQL injection protection' do\n  it 'prevents injection via name param' do\n    ...\n  end\nend"
}
```

`test_stub` 字段很关键——如果专家能为这个问题写一个测试骨架，就包含在这里。这个字段会触发特殊的 ASK 流程（见 Step 5a）。

### Step 4.6：收集与合并发现

**去重（Fingerprint Deduplication）**：

对每个发现计算指纹：
- 有 `fingerprint` 字段 → 用它
- 否则 → `{path}:{line}:{category}`（有行号时）或 `{path}:{category}`

相同指纹的发现：保留置信度最高的，标记 **"MULTI-SPECIALIST CONFIRMED"**，置信度 +1（上限 10）。

**PR 质量分**：
```
quality_score = max(0, 10 - (critical_count × 2 + informational_count × 0.5))
```

示例：3 个 CRITICAL 发现，4 个 INFORMATIONAL 发现：
```
quality_score = max(0, 10 - (3 × 2 + 4 × 0.5)) = max(0, 10 - 8) = 2
```
这个 PR 的质量分是 2/10。

**输出格式**：
```
SPECIALIST REVIEW: 5 findings (2 critical, 3 informational) from 3 specialists

[CRITICAL] (confidence: 9/10, specialist: security) app/auth.rb:15 — Token not validated before use
  Fix: Check token.expires_at > Time.now before granting access
  [MULTI-SPECIALIST CONFIRMED: security + testing]

[INFORMATIONAL] (confidence: 7/10, specialist: testing) app/services/user.rb:88 — Missing test for edge case
  Fix: Add test for empty email input

PR Quality Score: 5/10
```

### Red Team（红队，条件触发）

**触发条件**：`DIFF_LINES > 200` 或任何专家发现 CRITICAL 问题。

红队子 Agent 接收所有专家的发现摘要，任务是找出他们**遗漏的**内容：

> **Prompt 核心**："你是红队评审员。代码已经被 N 个专家评审，他们发现了以下问题：{merged findings}。你的任务是找出他们**遗漏的**内容。读取 checklist，运行 git diff，重点关注跨切面关注点和集成边界问题。"

红队专注于：
- 跨模块的交互问题（专家各看一个领域，不看交叉点）
- 集成边界（服务与服务之间的协议问题）
- 专家 checklist 的系统性盲区（每个专家都有固定的检查模式）

---

## Step 5：Fix-First Review（修复优先评审）

> **原文**：
> ```
> Every finding gets action — not just critical ones.
> ```

**核心设计哲学**：`/review` 不是"生成报告然后由人类去修"，而是"直接修，让人确认大的决策"。这是 Boil the Lake 原则的直接应用——AI 让修复成本接近零，所以应该直接修。

### Step 5.0：跨评审发现去重

```bash
~/.claude/skills/gstack/bin/gstack-review-read
```

读取当前分支所有之前评审的结果，找出用户之前主动跳过的发现（`action: "skipped"`）。

**抑制逻辑**：
- 发现的指纹在之前评审中被标记为 "skipped"
- 该发现涉及的文件在那次评审之后**没有**被修改

同时满足以上两条 → 静默抑制，不再提示用户。

> **用户体验设计**：用户已经决定接受的风险，不应该在每次评审时都被反复打扰。但如果相关代码改动了，可能引入了新风险，所以必须重新检查。

输出摘要：
```
Pre-Landing Review: N issues (X critical, Y informational)
Suppressed N findings from prior reviews (previously skipped by user)
```

### Step 5a：分类（AUTO-FIX vs ASK）

按照 checklist.md 中的 Fix-First 启发式规则分类：

| 分类 | 触发条件 | 典型例子 |
|------|---------|---------|
| **AUTO-FIX** | 机械性问题，方案明确，风险低 | N+1 查询加 `.includes()`、死代码删除、陈旧注释 |
| **ASK** | 关键问题、需要判断、可能有架构影响 | SQL 注入修复（需确认修复方式）、竞态条件（需确认锁策略） |

**test_stub 覆写规则**：如果发现包含 `test_stub` 字段，强制变为 ASK——写测试需要用户确认文件路径和测试框架约定：

```
[ASK] app/models/user.rb:42 — SQL injection in name lookup
  Proposed fix: Use User.where(name: name)
  Proposed test (spec/models/user_spec.rb):
    describe '#find_by_name' do
      it 'prevents SQL injection' do
        expect { User.find_by_name("'); DROP TABLE users;--") }.not_to raise_error
        expect(User.find_by_name("'; DROP TABLE users;--")).to be_nil
      end
    end
  → A) Fix + create test  B) Fix without test  C) Skip
```

### Step 5b：自动修复所有 AUTO-FIX 项目

对每个 AUTO-FIX 项，直接用 Edit/Write 工具修改文件：

```
[AUTO-FIXED] app/models/post.rb:88 — N+1 query → added .includes(:author)
[AUTO-FIXED] app/helpers/user_helper.rb:42 — dead code removed (unreachable after refactor)
[AUTO-FIXED] config/database.yml:15 — hardcoded password → use ENV['DB_PASSWORD']
```

### Step 5c：批量询问 ASK 项目

> **原文**：
> ```
> If there are ASK items remaining, present them in ONE AskUserQuestion:
> List each item with severity, problem, and recommended fix.
> Per-item options: A) Fix  B) Skip
> Include an overall RECOMMENDATION
> ```

**示例输出**：
```
I auto-fixed 5 issues. 2 need your input:

1. [CRITICAL] app/models/post.rb:42 — Race condition in status transition
   Problem: Two concurrent requests can both pass the 'draft' check and both publish
   Fix: Add WHERE status = 'draft' to the UPDATE statement
   → A) Fix  B) Skip

2. [INFORMATIONAL] app/services/generator.rb:88 — LLM output not type-checked
   Problem: LLM response written directly to user.role without validation
   Fix: Add whitelist check: raise unless VALID_ROLES.include?(role)
   → A) Fix  B) Skip

RECOMMENDATION: Fix both — #1 is a real race condition that will hit in production
with concurrent users, #2 prevents silent privilege escalation.
```

> 如果 ASK 项目 ≤ 3 个，可以用单独的 AskUserQuestion 逐一处理，而不是合并。

### Verification of Claims（声明核实）

> **原文**：
> ```
> - If you claim "this pattern is safe" → cite the specific line proving safety
> - If you claim "this is handled elsewhere" → read and cite the handling code
> - If you claim "tests cover this" → name the test file and method
> - Never say "likely handled" or "probably tested" — verify or flag as unknown
> ```

**核心原则**：禁止含糊声明。

| 含糊说法 | 要求 |
|---------|------|
| "这个模式安全" | 引用证明安全的具体代码行 |
| "这在其他地方处理了" | 读并引用处理代码（文件名 + 行号） |
| "测试覆盖了这个" | 说出测试文件名和测试方法名 |
| "可能是误报" | 要么核实是误报并给出证据，要么标注为 "unverified" |

> **Rationalization Prevention（防止合理化）**："这看起来没问题"不是一个有效的发现处理结果。要么有证据说明没问题，要么标记为未验证。AI 最容易犯的错误是"看起来像"——看起来像参数化查询，实际上是字符串拼接。

---

## Step 5.5：TODOS.md 交叉引用

> **原文**：
> ```
> - Does this PR close any open TODOs?
> - Does this PR create work that should become a TODO?
> - Are there related TODOs providing context for this review?
> ```

三个方向的交叉引用：
1. **关闭 TODO**：PR 解决了哪些已有的 TODO 项
2. **创建 TODO**：PR 引入了需要后续跟踪的工作（如"这里先用简单实现，后续优化"）
3. **相关 TODO**：有没有 TODO 能帮助理解当前评审的上下文

---

## Step 5.6：文档陈旧检查

> **原文**：
> ```
> For each .md file in the repo root, check if code changes affect features
> described in that doc. If doc NOT updated but code it describes WAS changed:
> "Documentation may be stale: [file] — consider running /document-release"
> ```

检查 `README.md`、`ARCHITECTURE.md`、`CONTRIBUTING.md`、`CLAUDE.md` 等：如果这些文档描述的功能在本次 diff 中被修改了，但文档本身没有更新，标记为 INFORMATIONAL 发现。

修复动作是 `/document-release`，而不是 `/review` 直接改文档。这是职责分离——`/review` 发现问题，专门的技能来处理。

---

## Step 5.7：对抗性评审（Adversarial Review，永远开启）

> **原文**：
> ```
> Every diff gets adversarial review from both Claude and Codex.
> LOC is not a proxy for risk — a 5-line auth change can be critical.
> ```

对抗性评审有三层：

```
层 1：Claude 对抗子 Agent（始终运行）
  ↓ 独立 Agent，全新上下文，无检查清单偏见
  ↓ Prompt："像攻击者和混沌工程师一样思考..."

层 2：Codex 对抗挑战（有 codex 可用时）
  ↓ 独立 AI 模型（OpenAI），不同的训练数据和推理风格
  ↓ 模式："find ways this code will fail in production"

层 3：Codex 结构化评审（DIFF_LINES >= 200 时）
  ↓ codex review --base <base>，找到 [P1] 标记
  └─► [P1] 发现 → GATE: FAIL → AskUserQuestion 是否修复
```

**为什么 "LOC is not a proxy for risk"**：5 行的 auth 变更可以比 500 行的 CRUD 危险得多。对抗性评审不看代码量，看的是变更的敏感程度。

**Claude 对抗子 Agent 的 Prompt 要点**：

> "Read the diff for this branch with `git diff origin/<base>`. Think like an attacker and a chaos engineer. Your job is to find ways this code will fail in production. Look for: edge cases, race conditions, security holes, resource leaks, failure modes, silent data corruption, logic errors that produce wrong results silently, error handling that swallows failures, and trust boundary violations. Be adversarial. Be thorough. No compliments — just the problems. For each finding, classify as FIXABLE (you know how to fix it) or INVESTIGATE (needs human judgment)."

**FIXABLE findings** → 进入 Fix-First 流程
**INVESTIGATE findings** → 展示为 INFORMATIONAL，供人工判断

### 跨模型综合报告

```
ADVERSARIAL REVIEW SYNTHESIS (always-on, N lines):
════════════════════════════════════════════════════
  High confidence (多个来源确认): [多个 pass 都同意的发现]
  Unique to Claude structured review: [结构化评审发现，其他未发现]
  Unique to Claude adversarial: [对抗子 Agent 发现，其他未发现]
  Unique to Codex: [Codex 发现，Claude 未发现]
  Models used: Claude structured ✓  Claude adversarial ✓/✗  Codex ✓/✗
════════════════════════════════════════════════════
```

**高置信度发现（多个来源同意）优先修复。** 如果 Claude 结构化评审、Claude 对抗子 Agent 和 Codex 都独立发现了同一个问题，这个问题是真实的概率非常高。

---

## Step 5.8：持久化评审结果

> **原文**：
> ```
> After all review passes complete, persist the final /review outcome so /ship
> can recognize that Eng Review was run on this branch.
> ```

```bash
~/.claude/skills/gstack/bin/gstack-review-log '{
  "skill": "review",
  "timestamp": "2024-01-15T10:30:00Z",
  "status": "clean",
  "issues_found": 0,
  "critical": 0,
  "informational": 0,
  "quality_score": 9.5,
  "specialists": {
    "testing": {"dispatched": true, "findings": 0, "critical": 0, "informational": 0},
    "security": {"dispatched": false, "reason": "scope"},
    "performance": {"dispatched": true, "findings": 1, "critical": 0, "informational": 1}
  },
  "findings": [
    {"fingerprint": "app/models/user.rb:42:sql-safety", "severity": "CRITICAL", "action": "fixed"},
    {"fingerprint": "app/services/post.rb:88:n-plus-one", "severity": "INFORMATIONAL", "action": "auto-fixed"}
  ],
  "commit": "abc1234"
}'
```

**字段说明**：

| 字段 | 含义 | 重要性 |
|------|------|--------|
| `status` | "clean" 或 "issues_found" | `/ship` 用来判断 CLEARED |
| `quality_score` | PR 质量分（0-10） | 趋势追踪 |
| `specialists` | 每个专家的命中统计 | 自适应门控学习 |
| `findings` | 每个发现的指纹 + 处理动作 | 跨评审去重（Step 5.0） |
| `commit` | 当前 HEAD 短 SHA | 追踪代码版本 |

**`action` 的三种值**：
- `"auto-fixed"` — AUTO-FIX，直接修复
- `"fixed"` — 用户批准修复
- `"skipped"` — 用户选择跳过

> **集成价值**：`/ship` 的 Review Readiness Dashboard 会读取这个文件，判断 Eng Review 是否已运行、结果是否 CLEARED。这是 gstack 工作流链路集成的核心机制。

---

## Capture Learnings（捕获经验）

> **原文**：
> ```
> If you discovered a non-obvious pattern, pitfall, or architectural insight
> during this session, log it for future sessions.
> A good test: would this insight save 5+ minutes in a future session?
> ```

```bash
~/.claude/skills/gstack/bin/gstack-learnings-log '{
  "skill": "review",
  "type": "pitfall",
  "key": "billing-service-missing-transaction",
  "insight": "BillingService.charge() does not use @Transactional — partial charges possible if email fails",
  "confidence": 9,
  "source": "observed",
  "files": ["src/main/java/com/example/service/BillingService.java"]
}'
```

**经验类型**：

| 类型 | 含义 | 好的例子 |
|------|------|---------|
| `pattern` | 可复用的方法 | "这个项目用 Sidekiq 处理异步任务，不用原生 Thread" |
| `pitfall` | 应该避免的陷阱 | "Order 状态转换没有乐观锁，会并发冲突" |
| `preference` | 用户明确表达的偏好 | "用户偏好 RSpec over MiniTest" |
| `architecture` | 结构性设计决策 | "Auth 模块采用 JWT，不用 session cookie" |
| `tool` | 库/框架使用见解 | "MyBatis 的 ${} 是字符串拼接，不是参数化" |
| `operational` | 项目环境/CLI 知识 | "运行测试需要先 docker compose up db" |

**files 字段的作用**：记录这个经验与哪些文件相关。如果这些文件后来被删除，经验可以被标记为"可能过时"，避免陈旧经验误导未来评审。

---

## 完整工作流 ASCII 流程图

```
用户: /review
    │
    ├── [Preamble Tier 4]
    │   ├── 环境初始化（版本检查、telemetry、session 追踪）
    │   ├── Boil the Lake 原则介绍（首次）
    │   ├── ROUTING 注入检查
    │   ├── Vendoring 检测
    │   └── Context Recovery（从历史 artifacts 恢复上下文）
    │
    ├── [Step 0] 检测平台（GitHub/GitLab/unknown）
    │   └── 确定基础分支名 <base>，后续所有命令使用
    │
    ├── [Step 1] 分支检查
    │   ├── 在基础分支上 → 结束（Nothing to review）
    │   └── 无 diff → 结束（同上）
    │
    ├── [Step 1.5] Scope Drift Detection
    │   ├── 读取 TODOS.md / PR描述 / commit messages
    │   ├── 识别 SCOPE CREEP（做了多余的事）
    │   ├── 识别 MISSING REQUIREMENTS（遗漏了该做的）
    │   └── 输出 Scope Check: CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING
    │       └── 仅报告，不阻塞（INFORMATIONAL）
    │
    ├── [Plan File Discovery]
    │   ├── 搜索计划文件（会话上下文 → 文件系统搜索）
    │   ├── 提取可操作项目（Checkbox / 编号步骤 / 祈使句）
    │   ├── Cross-Reference 分类：DONE / PARTIAL / NOT DONE / CHANGED
    │   └── HIGH impact NOT DONE → AskUserQuestion（门禁）
    │
    ├── [Step 2] 读取 checklist.md
    │   └── 失败 → STOP（硬性要求）
    │
    ├── [Step 2.5] Greptile 评审评论检查
    │   ├── 无 PR / gh 失败 → 静默跳过
    │   └── 有评论 → 分类：VALID / ALREADY FIXED / FP / SUPPRESSED
    │
    ├── [Step 3] git fetch origin <base> && git diff origin/<base>
    │
    ├── [Prior Learnings] 搜索历史经验
    │   └── 匹配发现时显示 "Prior learning applied: ..."
    │
    ├── [Step 4] Critical Pass（核心评审）
    │   ├── CRITICAL: SQL & Data Safety
    │   │   ├── SQL 注入（字符串拼接 vs 参数化）
    │   │   ├── 迁移安全（DROP COLUMN / 无默认值非空列）
    │   │   └── 事务边界（批量操作缺 @Transactional）
    │   ├── CRITICAL: Race Conditions & Concurrency
    │   │   ├── TOCTOU（check-then-use 竞态）
    │   │   ├── 状态转换缺乏原子性
    │   │   └── 线程安全（HashMap / SimpleDateFormat）
    │   ├── CRITICAL: LLM Output Trust Boundary
    │   │   ├── LLM 输出未验证直接写 DB
    │   │   ├── LLM 输出未清理直接渲染 HTML
    │   │   └── 链式提示注入风险
    │   ├── CRITICAL: Shell Injection
    │   │   └── 用户输入拼入 shell 命令
    │   ├── CRITICAL: Enum & Value Completeness
    │   │   └── 新枚举值 → Grep 所有 switch-case → 检查是否处理
    │   └── INFORMATIONAL: Async/Sync / Type Coercion / N+1 / ...
    │
    ├── [Step 4.5] Review Army 专家并行派遣
    │   ├── 检测 DIFF_LINES 和 SCOPE_* 变量
    │   ├── DIFF_LINES < 50 → 跳过所有专家
    │   ├── 总是派遣：Testing + Maintainability
    │   ├── 条件派遣：Security / Performance / Data Migration / API / Design
    │   ├── 自适应门控（历史零发现 → 自动跳过，Security/Migration 永不门控）
    │   └── 所有专家同时启动（Agent 并行）→ 输出 JSON Lines 发现
    │
    ├── [Step 4.6] 收集与合并发现
    │   ├── 指纹去重
    │   ├── MULTI-SPECIALIST CONFIRMED → 置信度 +1
    │   ├── 置信度门控（< 5 移到附录）
    │   └── 计算 PR Quality Score = max(0, 10 - critical×2 - info×0.5)
    │
    ├── [Red Team] 条件触发（DIFF > 200 或有 CRITICAL）
    │   └── 独立子 Agent，专找专家遗漏的内容
    │
    ├── [Step 5] Fix-First Review
    │   ├── [5.0] 跨评审去重（压制之前跳过且代码未变的发现）
    │   ├── [5a] 分类：AUTO-FIX vs ASK（含 test_stub 覆写规则）
    │   ├── [5b] AUTO-FIX → 直接修改文件
    │   ├── [5c] ASK → 一次 AskUserQuestion 批量询问
    │   └── [5d] 应用用户批准的修复
    │
    ├── [Step 5.5] TODOS.md 交叉引用
    │   ├── 此 PR 关闭了哪些 TODO？
    │   └── 此 PR 创建了哪些新 TODO？
    │
    ├── [Step 5.6] 文档陈旧检查
    │   └── 代码改了但 README/ARCH 没改 → INFORMATIONAL，建议 /document-release
    │
    ├── [Step 5.7] 对抗性评审（始终运行）
    │   ├── Claude 对抗子 Agent（始终）
    │   │   ├── FIXABLE → Fix-First 流程
    │   │   └── INVESTIGATE → INFORMATIONAL 报告
    │   ├── Codex 对抗挑战（有 codex 时）
    │   └── Codex 结构化评审（DIFF >= 200 行时）
    │       └── 发现 [P1] → GATE: FAIL → AskUserQuestion
    │
    ├── [Step 5.8] 持久化评审结果到 reviews.jsonl
    │   ├── status: "clean" / "issues_found"
    │   ├── quality_score: X/10
    │   ├── specialists: 每个专家的命中统计（自适应门控学习）
    │   └── findings: 每个发现的指纹 + action（跨评审去重数据）
    │
    └── [Capture Learnings] 记录有价值的经验
        └── 条件：非显而易见 && 能节省 5+ 分钟
```

---

## Important Rules（重要规则）

> **原文**：
> ```
> - Read the FULL diff before commenting. Do not flag issues already addressed in the diff.
> - Fix-first, not read-only. AUTO-FIX items are applied directly. ASK items only after
>   user approval. Never commit, push, or create PRs — that's /ship's job.
> - Be terse. One line problem, one line fix. No preamble.
> - Only flag real problems. Skip anything that's fine.
> ```

**逐条解读**：

| 规则 | 含义 | 反例 |
|------|------|------|
| **读完整 diff 再评论** | 避免报告 diff 后面已经修复的问题 | "第 42 行有 SQL 注入"但 diff 第 200 行已修复 |
| **Fix-First，不是只读** | 直接修代码，不是生成待办列表 | 生成报告"请修复以下问题..." |
| **不要 commit/push** | 修复代码，但不提交——那是 `/ship` 的职责 | 修完后 `git commit -m "fix: ..."` |
| **简洁** | 一行问题，一行修复，没有废话 | "我注意到这里可能存在一个潜在的问题..." |
| **只报真实问题** | 没问题的代码不要报 | 报告"这里可以写得更优雅" |

---

## Pass/Fail 机制分析

`/review` 没有单一的 PASS/FAIL 判决——它有多个层次的门禁：

### 层次 1：早期退出（不算 FAIL）
- 在基础分支上 → 结束，不是失败
- 无 diff → 结束，不是失败

### 层次 2：硬性阻塞
- **checklist.md 不可读** → STOP，评审无法继续

### 层次 3：HIGH Impact NOT DONE（Plan Audit）
- 计划中 HIGH 优先级项目完全未实现 → AskUserQuestion 门禁
- 用户选择 A（停下实现）→ 评审暂停，等待实现
- 用户选择 B（继续 + P1 TODO）→ 评审继续
- 用户选择 C（有意删除）→ 评审继续

### 层次 4：Codex 结构化评审 Gate
- `[P1]` 标记 → GATE: FAIL → AskUserQuestion
- 用户选择 A（调查并修复）→ 评审暂停，修复后重新运行
- 用户选择 B（继续）→ 评审继续，但 gate 状态记录为 FAIL

### 层次 5：最终状态记录
- `status: "clean"` → 所有发现都被解决（auto-fixed / fixed）
- `status: "issues_found"` → 有未解决的发现（包括被 skip 的）

`/ship` 读取 `status` 字段，判断是否 CLEARED。`"clean"` 才算 CLEARED。

---

## 设计核心思路汇总

| 设计决策 | 原则 | 说明 |
|---------|------|------|
| **Fix-First，不是 Read-Only** | 行动导向 | 发现问题直接修复，AI 让修复成本接近零 |
| **置信度分数** | 诚实性 | 每个发现量化置信度，低置信度移到附录 |
| **声明核实规则** | 防止合理化 | 禁止"可能安全"，必须引用具体代码行 |
| **专家并行评审** | 覆盖率 | 不同领域专家独立运行，避免主评审的系统性盲区 |
| **自适应门控** | 效率 | 历史零发现的专家自动跳过，Security/Migration 永不门控 |
| **MULTI-SPECIALIST CONFIRMED** | 置信度提升 | 多专家同意 → 置信度 +1，优先处理 |
| **跨评审去重** | 用户体验 | 用户跳过的发现在代码未变时不再反复提示 |
| **对抗性评审始终开启** | 防御深度 | 结构化评审有盲区，攻击者视角补充 |
| **枚举值完整性读 diff 外代码** | 系统性 | 新枚举值的影响不在 diff 里，必须主动搜索 |
| **计划完成度审计** | 完整性 | 先确认做了正确的事，再评价做的方式 |
| **Scope Drift 检测** | 完整性 | 先确认范围，再评审质量 |
| **持久化结果** | 系统集成 | `/ship` 的 Review Readiness Dashboard 依赖这个 |
| **经验积累** | 复利效应 | 每次评审都是下次的历史参考，随时间变聪明 |
| **Preamble Tier 4** | 优先级 | 最高级前置上下文，与 `/ship` 同级，强调关键性 |

---

## 与 gstack 其他技能的协作关系

```
/office-hours  ──────────────────────────────────────────────►
   产出：设计文档（DESIGN.md）

/plan-eng-review  ────────────────────────────────────────────►
   输入：设计文档
   产出：锁定的执行方案，记录到 gstack 项目目录

/review  ──────────────────────────────────────────────────────►
   输入：git diff（代码实现）+ 历史计划文件（如有）
   产出：修复后的代码 + reviews.jsonl 评审记录

/qa  ──────────────────────────────────────────────────────────►
   输入：运行中的应用
   产出：QA 报告 + bug 修复

/ship  ────────────────────────────────────────────────────────►
   输入：reviews.jsonl（检查 /review 是否通过）
   产出：PR + 版本号 + CHANGELOG

/land-and-deploy  ─────────────────────────────────────────────►
   输入：PR
   产出：merged + deployed + canary 监控
```

---

## 快速参考：Java/Spring 项目常见检查点

由于本文档面向 Java（Spring Boot + MyBatis）团队，整理以下最常见的 `/review` 检查点：

### SQL 安全
```xml
<!-- ❌ 危险：${} 是字符串拼接 -->
WHERE name = '${name}'

<!-- ✅ 安全：#{} 是参数化 -->
WHERE name = #{name}

<!-- ❌ 危险：ORDER BY 用 ${} -->
ORDER BY ${column}  <!-- 恶意输入可以注入任意 SQL -->

<!-- ✅ 安全：动态排序用白名单 -->
ORDER BY #{validatedColumn}  <!-- 先在 Java 代码中验证列名 -->
```

### 事务边界
```java
// ❌ 危险：批量操作无事务，部分失败导致数据不一致
public void batchCreate(List<Item> items) {
    for (Item item : items) {
        itemMapper.insert(item);  // 第 5 个失败，前 4 个已提交
    }
}

// ✅ 安全：整个批量操作在一个事务中
@Transactional
public void batchCreate(List<Item> items) {
    for (Item item : items) {
        itemMapper.insert(item);  // 任何一个失败，全部回滚
    }
}
```

### 并发竞态
```java
// ❌ 危险：TOCTOU，两个线程可能同时通过检查
if (order.getStatus() == OrderStatus.PENDING) {
    orderMapper.updateStatus(id, OrderStatus.PROCESSING);
}

// ✅ 安全：原子 CAS（Compare-And-Swap）更新
int affected = orderMapper.updateStatusWhere(
    id, OrderStatus.PROCESSING, OrderStatus.PENDING
);
if (affected == 0) {
    throw new ConcurrentModificationException("Order already processed");
}
```

### LLM 输出验证
```java
// ❌ 危险：LLM 输出直接赋值给敏感字段
String role = llmService.extractRole(response);
user.setRole(role);  // LLM 可能被诱导输出 "ADMIN"

// ✅ 安全：白名单验证
String role = llmService.extractRole(response);
Set<String> validRoles = Set.of("USER", "EDITOR");
if (!validRoles.contains(role)) {
    throw new IllegalArgumentException("Invalid role from LLM: " + role);
}
user.setRole(role);
```

### Kafka 消费幂等性
```java
// ❌ 危险：消息可能被重复消费，无幂等保障
@KafkaListener(topics = "order-created")
public void handleOrderCreated(OrderEvent event) {
    orderService.processOrder(event.getOrderId());  // 重复处理
}

// ✅ 安全：检查是否已处理（幂等键）
@KafkaListener(topics = "order-created")
public void handleOrderCreated(OrderEvent event) {
    if (processedEvents.contains(event.getMessageId())) {
        return;  // 已处理，跳过
    }
    orderService.processOrder(event.getOrderId());
    processedEvents.add(event.getMessageId());
}
```

---

> **本文档生成于 2026-04-07，对应 gstack review 技能 v1.0.0。**
> 源文件 1467 行，本注解 900+ 行，涵盖所有核心流程、设计原理和实践指南。
