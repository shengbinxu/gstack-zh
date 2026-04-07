# `/learn` 技能逐段中英对照注解

> 对应源文件：[`learn/SKILL.md`](https://github.com/garrytan/gstack/blob/main/learn/SKILL.md)（707 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## 一、技能定位总览

`/learn` 是 gstack 的**项目知识管理中心**。它不主动做任何代码变更——它是其他技能的"副产品收集器"。

当你运行 `/investigate`、`/review`、`/ship`、`/qa` 等技能时，Claude 会在执行过程中发现项目特有的规律、坑和偏好。这些发现通过 `gstack-learnings-log` 命令写入 `learnings.jsonl` 文件。`/learn` 技能让你查看、搜索、整理、导出这些积累下来的知识。

```
                      其他技能执行时
                           │
           ┌───────────────┼───────────────┐
           │               │               │
       /investigate    /review         /ship
           │               │               │
           └───────────────┼───────────────┘
                           │ 发现规律/坑/偏好
                           ▼
                  gstack-learnings-log
                           │
                           ▼
            ~/.gstack/projects/<slug>/
                    learnings.jsonl
                           │
                    /learn 读取管理
                           │
           ┌───────┬───────┼───────┬───────┐
           │       │       │       │       │
        查看    搜索    剪枝    导出    统计
```

**与 CLAUDE.md 的关系**：`learnings.jsonl` 存储在用户目录（`~/.gstack/`），不在项目里。CLAUDE.md 是人工维护的项目指令；`learnings.jsonl` 是 AI 自动发现的知识积累。两者互补：CLAUDE.md 写你已知的规则，`learnings.jsonl` 积累你运行过程中发现的规律。

**项目级 vs 全局级**：learnings 是**项目级**的——每个项目有自己的 `learnings.jsonl`，通过 `gstack-slug`（从项目路径/git remote 生成的稳定标识符）隔离。不同项目的知识不会混用。

---

## 二、Frontmatter（元数据区）

> **原文**：
> ```yaml
> ---
> name: learn
> preamble-tier: 2
> version: 1.0.0
> description: |
>   Manage project learnings. Review, search, prune, and export what gstack
>   has learned across sessions. Use when asked to "what have we learned",
>   "show learnings", "prune stale learnings", or "export learnings".
>   Proactively suggest when the user asks about past patterns or wonders
>   "didn't we fix this before?"
> allowed-tools:
>   - Bash
>   - Read
>   - Write
>   - Edit
>   - AskUserQuestion
>   - Glob
>   - Grep
> ---
> ```

**中文翻译**：

- **name: learn** — 用户输入 `/learn` 触发此技能。
- **preamble-tier: 2** — Preamble 级别 2（轻量级）。不包含 repo 模式检测、Search Before Building 等高级上下文。tier 2 是"知道环境、会话管理"的最小集合。
- **description**：管理项目 learnings。回顾、搜索、剪枝和导出 gstack 跨会话学到的东西。当用户问"我们学到了什么"、"显示 learnings"、"剪枝陈旧 learnings"或"导出 learnings"时触发。当用户询问过去的规律或疑惑"我们之前不是修过这个吗？"时主动建议。
- **preamble-tier 对比**：

| Tier | 典型技能 | 额外上下文 |
|------|---------|-----------|
| 1 | 极简技能 | 无额外上下文 |
| 2 | `/learn`、`/checkpoint` | 会话管理、更新检查 |
| 3 | `/plan-eng-review`、`/review` | + repo 模式检测、Search Before Building |
| 4 | `/ship`、`/qa` | + 完整 boilerplate、所有上下文 |

- **allowed-tools**：注意有 `Write` 和 `Edit` ——`/learn prune` 时需要修改 `learnings.jsonl` 文件；`/learn export` 时可以追加到 CLAUDE.md。这与只读的 `/plan-eng-review` 不同。

---

## 三、Preamble 核心逻辑（运行时初始化）

preamble 是每个技能启动时必须首先执行的初始化 bash 脚本。tier 2 的内容如下：

### 3.1 环境检查与会话追踪

> **原文节选**：
> ```bash
> _UPD=$(~/.claude/skills/gstack/bin/gstack-update-check 2>/dev/null || ...)
> mkdir -p ~/.gstack/sessions
> touch ~/.gstack/sessions/"$PPID"
> _SESSIONS=$(find ~/.gstack/sessions -mmin -120 -type f 2>/dev/null | wc -l | tr -d ' ')
> ```

**中文**：检查 gstack 版本更新。创建会话目录并记录父进程 ID（PPID）作为会话标识。统计过去 120 分钟内的活跃会话数（`_SESSIONS`）。超过 120 分钟的会话文件自动清理——这防止会话目录无限增长。

### 3.2 分支与配置检测

> **原文节选**：
> ```bash
> _BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
> _PROACTIVE=$(~/.claude/skills/gstack/bin/gstack-config get proactive 2>/dev/null || echo "true")
> _SKILL_PREFIX=$(~/.claude/skills/gstack/bin/gstack-config get skill_prefix 2>/dev/null || echo "false")
> source <(~/.claude/skills/gstack/bin/gstack-repo-mode 2>/dev/null) || true
> ```

**中文**：获取当前 git 分支名。读取 `proactive` 配置（是否主动建议技能）。读取 `skill_prefix` 配置（是否用 `/gstack-` 前缀）。检测 repo 模式（REPO_MODE：solo/team/unknown）。

### 3.3 Learnings 数量检测

> **原文节选**：
> ```bash
> eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)" 2>/dev/null || true
> _LEARN_FILE="${GSTACK_HOME:-$HOME/.gstack}/projects/${SLUG:-unknown}/learnings.jsonl"
> if [ -f "$_LEARN_FILE" ]; then
>   _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" 2>/dev/null | tr -d ' ')
>   echo "LEARNINGS: $_LEARN_COUNT entries loaded"
>   if [ "$_LEARN_COUNT" -gt 5 ] 2>/dev/null; then
>     ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 3 2>/dev/null || true
>   fi
> else
>   echo "LEARNINGS: 0"
> fi
> ```

**中文**：这是 `/learn` 技能特有的 preamble 扩展。计算 `learnings.jsonl` 的行数（等同于条目数）。如果超过 5 条，自动显示最新 3 条作为上下文热身。

**设计原理**：为什么其他技能的 preamble 也有这段代码？因为这段代码在**所有**技能的 preamble 里都存在（tier 2+）。每次启动任何技能，都会加载当前项目的 learnings 数量，让 Claude 知道有多少历史知识可用。这是 gstack 跨会话记忆的核心机制。

---

## 四、learnings.jsonl 格式详解

learnings 以 JSONL 格式存储（每行一个 JSON 对象）。路径：
```
~/.gstack/projects/<SLUG>/learnings.jsonl
```

### 4.1 完整字段结构

```json
{
  "skill": "investigate",
  "type": "pitfall",
  "key": "auth-token-undefined-on-expiry",
  "insight": "auth.ts:47 的 token check 在 session 过期时返回 undefined 而非 false，导致 API 返回 500 而非 401",
  "confidence": 0.9,
  "source": "observed",
  "files": ["src/auth.ts", "src/middleware/auth.middleware.ts"],
  "ts": "2026-04-07T10:23:45Z"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `skill` | string | 哪个技能记录了这条 learning |
| `type` | string | 6种类型之一（见下） |
| `key` | string | 短标识符，kebab-case，2-5个词 |
| `insight` | string | 一句话描述，具体到文件/行号 |
| `confidence` | float | 0.0-1.0，置信度 |
| `source` | string | `observed`（AI发现）或 `user-stated`（用户告知） |
| `files` | array | 相关文件路径（可选） |
| `ts` | string | ISO 8601 时间戳 |

### 4.2 去重机制（append-only，最新获胜）

`learnings.jsonl` 是**只追加**（append-only）的文件。同一个 `key` 可能有多条记录（随时间演变）。查询时，相同 `key` 取最新一条：

```
learnings.jsonl:
{"key":"db-migration-order","insight":"先跑 schema，再跑 data","confidence":0.7,"ts":"2026-01-01"}
{"key":"db-migration-order","insight":"schema 和 data 必须在同一事务，否则回滚不完整","confidence":0.9,"ts":"2026-03-15"}
                                                              ↑
                                                     查询时取这条（更新、置信度更高）
```

**设计原理**：append-only 避免了并发写冲突，也保留了知识的演化历史。置信度的提升反映了从"怀疑"到"确认"的过程。

---

## 五、6 种 Learning 类型详解

> **原文**（来自 `/learn add` 的 AskUserQuestion）：
> Type (pattern / pitfall / preference / architecture / tool)

实际使用中有 6 种类型（`/learn stats` 的 BY_TYPE 输出）：

```
┌─────────────────┬──────────────────────────────────┬──────────────────────────────┐
│ 类型            │ 含义                              │ 典型来源技能                  │
├─────────────────┼──────────────────────────────────┼──────────────────────────────┤
│ pattern         │ 项目中反复出现的代码规律           │ /review、/qa                 │
│ pitfall         │ 已知的坑，避免重踩                 │ /investigate、/qa            │
│ preference      │ 团队/用户的风格偏好               │ /review、用户直接告知         │
│ architecture    │ 系统设计决策和原理                │ /plan-eng-review             │
│ tool            │ 特定工具/命令的用法技巧            │ /ship、/investigate          │
│ operational     │ 运维类发现（构建顺序、环境变量等）  │ 任何技能的 Operational 节     │
└─────────────────┴──────────────────────────────────┴──────────────────────────────┘
```

### 类型示例

**pattern**（规律）：
```json
{
  "type": "pattern",
  "key": "service-layer-validation",
  "insight": "所有校验逻辑在 service 层做，controller 只转发，不做业务判断",
  "confidence": 0.85
}
```

**pitfall**（坑）：
```json
{
  "type": "pitfall",
  "key": "clickhouse-batch-insert-size",
  "insight": "单次 INSERT 超过 10w 行会触发 CH 内存限制，批量插入需分片处理",
  "confidence": 0.95,
  "files": ["src/data/clickhouse-writer.ts"]
}
```

**preference**（偏好）：
```json
{
  "type": "preference",
  "key": "error-response-format",
  "insight": "错误响应统一用 {code, message, data: null} 格式，不用 HTTP status 区分业务错误",
  "confidence": 1.0,
  "source": "user-stated"
}
```

**architecture**（架构）：
```json
{
  "type": "architecture",
  "key": "cqrs-read-write-separation",
  "insight": "写操作走 MySQL，读操作优先走 ES/ClickHouse，不允许在读接口直接查 MySQL",
  "confidence": 0.9
}
```

**tool**（工具技巧）：
```json
{
  "type": "tool",
  "key": "kafka-consumer-group-reset",
  "insight": "重置 consumer offset 需要先停消费者，用 kafka-consumer-groups.sh --reset-offsets --to-earliest",
  "confidence": 0.8
}
```

**operational**（运维）：
```json
{
  "type": "operational",
  "key": "mybatis-plus-wrapper-null-safe",
  "insight": "LambdaQueryWrapper 的 eq() 传入 null 时不报错但会生成 IS NULL 条件，需显式判断",
  "confidence": 0.85,
  "source": "observed"
}
```

---

## 六、confidence 评分机制

> **设计原理**：confidence 是 0.0-1.0 的浮点数，表示"这条 learning 有多可靠"。

```
confidence 演化时间线：

  首次观察到某个规律
        │
        ▼
  confidence: 0.6    (初步观察，不确定)
        │
        │ 同一规律在3个不同地方出现
        ▼
  confidence: 0.8    (规律确认)
        │
        │ 用户明确说"是的，这是我们的规范"
        ▼
  confidence: 1.0    (用户确认)
```

**不同来源的初始置信度**：

| source | 初始 confidence | 原因 |
|--------|----------------|------|
| `observed`（AI单次推断） | 0.6-0.8 | AI 可能推断错误 |
| `observed`（多次确认） | 0.85-0.95 | 重复出现更可靠 |
| `user-stated`（用户明确说明） | 0.9-1.0 | 用户是最终权威 |

**confidence 用于什么**？`/learn stats` 会显示平均置信度（`AVG_CONFIDENCE`）。preamble 在启动时显示最新 3 条 learnings，低置信度的条目暗示"这是推测，不是定论"。`/learn prune` 时，低置信度 + 引用文件已删除的条目优先剔除。

---

## 七、各子命令详解

### 7.1 `/learn`（默认：显示近期）

> **原文**：
> ```bash
> eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
> ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 20 2>/dev/null || echo "No learnings yet."
> ```
>
> Present the output in a readable format. If no learnings exist, tell the user:
> "No learnings recorded yet. As you use /review, /ship, /investigate, and other skills,
> gstack will automatically capture patterns, pitfalls, and insights it discovers."

**中文**：不带参数调用 `/learn` 时，显示最近 20 条 learnings，按类型分组展示。如果没有任何 learning，给出友好提示：告诉用户 learnings 会随着使用其他技能自动积累。

**输出示例**：
```
## Project Learnings (6 entries)

### Pitfalls
- **clickhouse-batch-size**: 单次插入超10w行触发内存限制 (confidence: 9/10)
- **auth-token-on-expiry**: session过期时token check返回undefined非false (confidence: 9/10)

### Patterns
- **service-layer-validation**: 校验逻辑统一在service层 (confidence: 8/10)

### Preferences
- **error-response-format**: 错误响应用{code,message,data:null}格式 (confidence: 10/10)

### Operational
- **mybatis-wrapper-null**: eq()传null生成IS NULL条件 (confidence: 8/10)
```

### 7.2 `/learn search <query>`（搜索）

> **原文**：
> ```bash
> ~/.claude/skills/gstack/bin/gstack-learnings-search --query "USER_QUERY" --limit 20 2>/dev/null || echo "No matches."
> ```
> Replace USER_QUERY with the user's search terms. Present results clearly.

**中文**：语义搜索 learnings。当你记得"我们遇到过某个问题"但不记得具体是什么时，用 `/learn search <关键词>` 查找。

**使用场景**：
```
/learn search clickhouse         → 所有与ClickHouse相关的learnings
/learn search auth               → 认证相关的pitfall和pattern
/learn search migration order    → 数据迁移顺序相关的记录
```

**设计原理**：`gstack-learnings-search` 的搜索是文本匹配（key + insight 字段），不是向量语义搜索。所以关键词要具体——搜"auth"比搜"登录问题"更有效。

### 7.3 `/learn prune`（剪枝）

这是最复杂的子命令。它检测**陈旧**和**矛盾**的 learnings。

> **原文**：
> ```
> For each learning in the output:
>
> 1. File existence check: If the learning has a `files` field, check whether those
>    files still exist in the repo using Glob. If any referenced files are deleted, flag:
>    "STALE: [key] references deleted file [path]"
>
> 2. Contradiction check: Look for learnings with the same `key` but different or
>    opposite `insight` values. Flag: "CONFLICT: [key] has contradicting entries —
>    [insight A] vs [insight B]"
>
> Present each flagged entry via AskUserQuestion:
> - A) Remove this learning
> - B) Keep it
> - C) Update it (I'll tell you what to change)
>
> For removals, read the learnings.jsonl file and remove the matching line, then write
> back. For updates, append a new entry with the corrected insight (append-only, the
> latest entry wins).
> ```

**中文**：

prune 的两种剔除机制：

```
┌─────────────────────────────────────────────────────────┐
│                   Prune 检测流程                         │
├─────────────────────────────────────────────────────────┤
│  读取最多100条learnings                                   │
│         │                                               │
│         ├──── 文件存在性检查                              │
│         │     • learning有files字段？                    │
│         │     • 用Glob检查文件是否还存在                  │
│         │     • 文件已删 → STALE标记                     │
│         │                                               │
│         └──── 矛盾检查                                   │
│               • 同一key有多条不同insight？                │
│               • 新insight与旧insight相反？               │
│               → CONFLICT标记                            │
│                                                         │
│  逐条通过AskUserQuestion处理：                            │
│  A) 删除  B) 保留  C) 更新                               │
└─────────────────────────────────────────────────────────┘
```

**为什么删除是"读取-过滤-写回"而不是直接 sed？**
因为 JSONL 文件需要精确匹配删除特定行，而 `sed -i` 在不同系统上行为不一致（macOS vs Linux）。用 Read + 过滤 + Write 更安全可控。

**更新为什么是 append 而非就地修改？**
保持 append-only 语义。最新条目获胜，旧条目保留为历史记录。这样即使更新出错，原始数据也不丢失。

### 7.4 `/learn export`（导出）

> **原文**：
> ```
> Format the output as a markdown section:
> ## Project Learnings
> ### Patterns
> - **[key]**: [insight] (confidence: N/10)
> ...
> Present the formatted output to the user. Ask if they want to append it to CLAUDE.md
> or save it as a separate file.
> ```

**中文**：将 learnings 导出为 Markdown 格式，可选择追加到 CLAUDE.md 或保存为独立文件。

**使用场景**：项目交接时、新成员加入时、做项目回顾时。导出的内容比 `learnings.jsonl` 更易读。

**与 CLAUDE.md 的整合**：导出并追加到 CLAUDE.md 后，这些知识就变成了"项目指令"的一部分，下次 Claude 启动任何技能都会读到（通过 preamble 的 CLAUDE.md 检测）。这是把 AI 积累的知识固化为团队规范的方法。

### 7.5 `/learn stats`（统计）

> **原文（核心脚本）**：
> ```bash
> cat "$LEARN_FILE" | bun -e "
>   const lines = (await Bun.stdin.text()).trim().split('\n').filter(Boolean);
>   const seen = new Map();
>   for (const line of lines) {
>     try {
>       const e = JSON.parse(line);
>       const dk = (e.key||'') + '|' + (e.type||'');
>       const existing = seen.get(dk);
>       if (!existing || new Date(e.ts) > new Date(existing.ts)) seen.set(dk, e);
>     } catch {}
>   }
>   ...
>   console.log('AVG_CONFIDENCE: ' + (totalConf / seen.size).toFixed(1));
> "
> ```

**中文**：统计 learnings 的健康度指标。注意去重逻辑：以 `key + type` 为唯一键，相同 key+type 只保留最新一条（`seen.set(dk, e)` 中时间戳更新的获胜）。

**输出示例**：
```
TOTAL: 23 entries (raw JSONL lines)
UNIQUE: 18 (after dedup by key+type)
BY_TYPE: {"pitfall":5,"pattern":4,"preference":3,"architecture":3,"tool":2,"operational":1}
BY_SOURCE: {"observed":15,"user-stated":3}
AVG_CONFIDENCE: 0.8
```

**AVG_CONFIDENCE 的意义**：
- 0.9+ → 大多数 learnings 已被确认，知识库可信
- 0.7-0.9 → 混合状态，建议运行 `/learn prune` 整理
- < 0.7 → 很多推测性记录，项目早期或 learnings 质量参差

### 7.6 `/learn add`（手动添加）

> **原文**：
> ```
> The user wants to manually add a learning. Use AskUserQuestion to gather:
> 1. Type (pattern / pitfall / preference / architecture / tool)
> 2. A short key (2-5 words, kebab-case)
> 3. The insight (one sentence)
> 4. Confidence (1-10)
> 5. Related files (optional)
>
> Then log it:
> ~/.claude/skills/gstack/bin/gstack-learnings-log '{"skill":"learn","type":"TYPE",...}'
> ```

**中文**：手动添加 learning，用 AskUserQuestion 收集必要信息。`source` 自动设置为 `"user-stated"`，代表用户直接陈述（比 AI 推断更可信）。

**key 命名规范**：
- kebab-case（全小写，连字符分隔）
- 2-5个词
- 描述"什么情况"，不是"怎么做"
- 好的例子：`clickhouse-batch-limit`、`auth-token-expiry-bug`、`db-migration-order`
- 坏的例子：`always-check-null`（太泛）、`the-auth-token-sometimes-returns-undefined-when-session-expires`（太长）

---

## 八、跨技能共享：谁会写入 learnings？

几乎所有 gstack 技能的末尾都有 **Operational Self-Improvement** 节：

> **原文（所有技能共用）**：
> ```
> Before completing, reflect on this session:
> - Did any commands fail unexpectedly?
> - Did you take a wrong approach and have to backtrack?
> - Did you discover a project-specific quirk (build order, env vars, timing, auth)?
> - Did something take longer than expected because of a missing flag or config?
>
> If yes, log an operational learning for future sessions:
> ~/.claude/skills/gstack/bin/gstack-learnings-log '{"skill":"SKILL_NAME","type":"operational",...}'
>
> A good test: would knowing this save 5+ minutes in a future session? If yes, log it.
> ```

**中文**：每个技能在完成时都会反思本次会话。发现了项目特有的怪癖就写入 learnings。"能节省未来 5 分钟"是日志记录的门槛。

**写入 learnings 的主要场景**：

```
┌──────────────────┬────────────────────────────────────┬──────────┐
│ 技能              │ 典型 learning 类型                  │ 频率      │
├──────────────────┼────────────────────────────────────┼──────────┤
│ /investigate     │ pitfall（根因分析中发现的坑）          │ 高        │
│ /review          │ pattern（代码中发现的规律）             │ 高        │
│ /ship            │ operational（构建/部署中的怪癖）        │ 中        │
│ /qa              │ pitfall（测试发现的边界情况）           │ 中        │
│ /plan-eng-review │ architecture（架构决策）               │ 低-中     │
│ /learn add       │ preference（用户手动输入）              │ 按需      │
│ /retro           │ pattern（跨周期统计规律）               │ 低        │
└──────────────────┴────────────────────────────────────┴──────────┘
```

---

## 九、与其他系统的关系

### 9.1 与 CLAUDE.md 的关系

```
CLAUDE.md                          learnings.jsonl
────────────────────               ──────────────────────────
• 人工维护                          • AI自动积累（+用户手动添加）
• 项目指令、规范、规则               • 跨会话发现的规律、坑、偏好
• 版本控制（在git repo里）           • 本地存储（~/.gstack/，不进git）
• 全团队可见                         • 当前用户可见
• 静态（需要人更新）                  • 动态（每次技能运行可能新增）
• 优先级高（Claude优先读）            • 补充性（preamble中加载）

整合路径：/learn export → 追加到CLAUDE.md → 固化为团队规范
```

### 9.2 与 Timeline 的关系

gstack 还维护 `timeline.jsonl`（技能运行历史）。learnings 和 timeline 的区别：

| | learnings.jsonl | timeline.jsonl |
|--|----------------|----------------|
| **内容** | 知识（规律、坑、偏好） | 事件（哪个技能何时运行） |
| **用途** | 跨会话知识传递 | 会话恢复、模式预测 |
| **格式** | 结构化 JSON，有 key/insight | 结构化 JSON，有 skill/event/outcome |
| **增长** | 按项目积累，会 prune | 按时间追加，不删除 |

---

## 十、Voice 节——gstack 的写作风格

> **原文节选**：
> ```
> Lead with the point. Say what it does, why it matters, and what changes for the builder.
> Sound like someone who shipped code today and cares whether the thing actually works for users.
>
> **Concreteness is the standard.** Name the file, the function, the line number.
> Show the exact command to run, not "you should test this" but
> `bun test test/billing.test.ts`.
>
> **Writing rules:**
> - No em dashes. Use commas, periods, or "..." instead.
> - No AI vocabulary: delve, crucial, robust, comprehensive...
> - Short paragraphs. Mix one-sentence paragraphs with 2-3 sentence runs.
> ```

**中文**：gstack 的 voice 哲学是"builder 对 builder"——直接说要点，不绕弯子。具体到文件名、函数名、行号。禁止"delve"、"crucial"、"robust"等 AI 腔调词。短段落，偶尔单句成段。

这段 voice 配置在**所有 tier 2+ 的技能里都存在**，确保 Claude 在所有交互中保持一致的风格。

---

## 十一、Completion Status Protocol

> **原文**：
> ```
> When completing a skill workflow, report status using one of:
> - DONE — All steps completed successfully. Evidence provided for each claim.
> - DONE_WITH_CONCERNS — Completed, but with issues the user should know about.
> - BLOCKED — Cannot proceed. State what is blocking and what was tried.
> - NEEDS_CONTEXT — Missing information required to continue.
> ```

**中文**：完成时必须用这四种状态之一汇报。不允许含糊地说"大概完成了"。`/learn` 技能的典型状态：

- `/learn`（查看）→ `DONE`（展示完 learnings）
- `/learn prune`（部分跳过）→ `DONE_WITH_CONCERNS`（"跳过了 3 条低置信度条目，建议人工复查"）
- `/learn stats`（learnings.jsonl 不存在）→ `DONE`（"No learnings yet."）
- `/learn export`（用户取消了追加到 CLAUDE.md）→ `DONE`（"Exported to console, not appended."）

---

## 十二、整体数据流总结

```
用户输入 "/learn [子命令]"
         │
         ▼
  ① 运行 Preamble bash 脚本
    • gstack-update-check
    • 会话管理
    • 读取 BRANCH / PROACTIVE / SKILL_PREFIX
    • gstack-slug → 确定项目 SLUG
    • 读取 _LEARN_FILE 路径
    • 显示当前 learnings 数量
         │
         ▼
  ② Proactive / SKILL_PREFIX / 升级检查
    • PROACTIVE=false → 不主动建议其他技能
    • SKILL_PREFIX=true → 使用 /gstack-learn 前缀
    • UPGRADE_AVAILABLE → 走升级流程
         │
         ▼
  ③ 首次启动检查（只执行一次）
    • LAKE_INTRO=no → 介绍 Boil the Lake 原则
    • TEL_PROMPTED=no → 遥测配置问答
    • PROACTIVE_PROMPTED=no → 主动模式配置问答
    • HAS_ROUTING=no → 建议添加 skill routing 到 CLAUDE.md
    • VENDORED_GSTACK=yes → 建议迁移到 team mode
         │
         ▼
  ④ Context Recovery
    • 读取最近 artifacts（ceo-plans、checkpoints）
    • 解析 timeline.jsonl → LAST_SESSION、RECENT_PATTERN
    • 如有 → 显示"欢迎回来"摘要
         │
         ▼
  ⑤ 解析用户命令
    • no args → Show recent
    • search → Search
    • prune → Prune
    • export → Export
    • stats → Stats
    • add → Manual add
         │
         ▼
  ⑥ 执行子命令逻辑
    （详见第七节）
         │
         ▼
  ⑦ Operational Self-Improvement
    • 反思本次会话
    • 发现值得记录的 operational learning？
    • gstack-learnings-log 写入
         │
         ▼
  ⑧ Telemetry（遥测，可选）
    • 记录技能运行时长和结果到 analytics/
         │
         ▼
  ⑨ 输出 DONE / DONE_WITH_CONCERNS / BLOCKED
```

---

## 十三、使用建议

**什么时候运行 `/learn`？**

1. **项目初期**：运行几周后，`/learn` 看看 AI 发现了什么规律，是否符合你的预期
2. **遇到"我们之前修过这个"**：`/learn search <关键词>` 快速定位历史记录
3. **项目交接前**：`/learn export` 导出所有 learnings，追加到 CLAUDE.md，让知识成为项目文档
4. **每月维护**：`/learn prune` 清理陈旧和矛盾的记录
5. **知识总结**：`/learn stats` 评估知识库健康度

**不适合用 `/learn` 做什么？**

- 不要用它作为"记笔记"的主要工具（用 CLAUDE.md 或飞书文档）
- 不要期望它跨项目共享知识（learnings 是项目级隔离的）
- 不要把临时信息记进去（learnings 应该是持久有效的规律）

---

*源文件：`/d/transsion/ai/gstack/learn/SKILL.md`（707 行）*
*注解版本：2026-04-07*
