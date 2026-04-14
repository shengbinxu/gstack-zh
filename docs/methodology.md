# gstack 研发方法论全景

> 本文解读 gstack 在完整研发生命周期中的工作方式：各个 skill 如何协作、关键工件（artifact）的生命周期、以及这套设计背后的核心理念。
> 
> 不是单个 skill 的说明，而是**整体方法论的全貌**。

---

## 一、核心理念（Ethos）

gstack 有三条贯穿全程的设计原则，写在 `ETHOS.md` 里：

| 原则 | 含义 |
|------|------|
| **Boil the Lake** | AI 使完成度的边际成本接近零 → 永远做完整版，不做捷径 |
| **Search Before Building** | 先查找（Layer 1 成熟方案 → Layer 2 流行方案 → Layer 3 第一性原理） |
| **User Sovereignty** | 用户永远决策，AI 只推荐。两个模型意见一致 ≠ 自动执行 |

这三条原则被硬编码进每个 skill 的 preamble（`{{PREAMBLE}}`），每次 skill 启动时自动加载。

---

## 二、研发生命周期时序图

```
IDEA
  │
  ▼
/office-hours ──────────────────────── 想法评估（可选）
  │                                    6 个逼问诊断产品可行性
  │                                    → builder-profile.jsonl
  ▼
PLAN（规划阶段：写设计文档、锁定架构）
  │
  ├──► /plan-ceo-review ──────────────── 范围决策（可选，推荐）
  │      expansion/hold/reduction 三种模式
  │      → ceo-plans/{date}-{slug}.md
  │
  ├──► /plan-eng-review ──────────────── 架构评审（可选，推荐）
  │      架构锁定 + 测试规划
  │      → {branch}-eng-review-test-plan-*.md
  │
  ├──► /plan-design-review ───────────── 设计评审（可选）
  │      视觉方向确认
  │      → designs/（目录）
  │
  ├──► /plan-devex-review ────────────── DX 评审（可选）
  │      开发者体验审计
  │
  ├──► /autoplan ─────────────────────── 一键跑完全部评审
  │      自动决策 + taste gate（关键决策点仍需用户确认）
  │      → reviews.jsonl 更新
  │
  ▼
DEVELOPMENT（开发循环：实现代码）
  │
  ├──► /qa ──────────────────────────── 运行时 QA 测试（可选）
  │      打开浏览器，系统性测试
  │      → learnings.jsonl（发现的 pitfall）
  │
  ├──► /investigate ──────────────────── 调试（遇到 bug 时）
  │      系统性根因分析
  │      → learnings.jsonl（根因 pattern）
  │
  └──► /checkpoint ───────────────────── 保存工作状态（随时）
         → checkpoint-$TS.json
  │
  ▼
/ship ──────────────────────────────── 交付（核心，全自动）
  │
  ├── Step 1    Pre-flight + Readiness Dashboard
  ├── Step 2    Merge base branch
  ├── Step 3    Run tests（in-branch failures → STOP）
  ├── Step 3.25 Eval suites（conditional，prompt 相关文件变更时）
  ├── Step 3.4  Coverage audit（低于阈值 → STOP）
  ├── Step 3.45 Plan completion audit（P0 必须完成）
  ├── Step 3.47 Plan verification（手动测试步骤验证）
  ├── Step 3.5  Pre-landing review（代码审查门禁）
  │             → AUTO-FIX（低风险自动修）
  │             → ASK（高风险问用户）
  │             → reviews.jsonl 写入结果
  ├── Step 4    Version bump（MICRO/PATCH 自动，MINOR/MAJOR 问用户）
  ├── Step 5    CHANGELOG 自动生成
  ├── Step 5.5  TODOS.md 自动更新（标记完成项）
  ├── Step 6    Commit + push
  └── Step 7    Create/update PR
  │
  ▼
POST-SHIP（发布后）
  │
  ├──► /document-release ─────────────── 更新文档（README/ARCHITECTURE/CONTRIBUTING）
  ├──► /land-and-deploy ──────────────── 合并 PR + 等待 CI + 部署验证
  ├──► /canary ───────────────────────── 金丝雀监控
  └──► /retro ────────────────────────── 周回顾（commit 历史分析）
```

---

## 三、关键工件（Artifact）生命周期表

### 3.1 项目级工件（`~/.gstack/projects/$SLUG/`）

| 工件 | 写入者 | 读取者 | 写入时机 | 用途 |
|------|-------|-------|---------|------|
| `learnings.jsonl` | 所有 skill（显式调用 `gstack-learnings-log`） | 所有 skill（preamble 自动加载） | skill 完成时 | 跨 session 学习积累：patterns、pitfalls、preferences、架构决策 |
| `timeline.jsonl` | 所有 skill（preamble 后台写入） | `/retro` | skill 开始/完成时 | 工作时间轴，非阻塞性日志 |
| `$BRANCH-reviews.jsonl` | `/review`、`/ship`（`gstack-review-log`） | `/ship` step 1（`gstack-review-read`） | 评审完成时 | 预登陆评审历史，readiness dashboard 数据源 |
| `ceo-plans/{date}-{slug}.md` | `/plan-ceo-review` | `/ship` step 1 dashboard | CEO review 完成时 | 范围决策记录 |
| `{user}-{branch}-eng-review-test-plan-*.md` | `/plan-eng-review` | `/qa`、`/ship` step 3 | eng review 完成时 | 测试计划，QA 的主要输入 |
| `designs/` （目录） | `/design-consultation`、`/design-shotgun` | `/plan-design-review` | design skill 完成时 | 设计方向记录，含 approved.json 等 |
| `checkpoint-$TS.json` | `/checkpoint` | `/checkpoint`（resume） | 用户手动调用时 | 工作状态快照，跨 session 恢复 |

### 3.2 全局工件（`~/.gstack/`）

| 工件 | 写入者 | 读取者 | 用途 |
|------|-------|-------|------|
| `builder-profile.jsonl` | `/office-hours` | `/office-hours`（通过 `gstack-builder-profile` 脚本读取，决定 tier 和个性化行为） | 全局构建者档案：session 次数、tier、累积信号、资源展示历史 |
| `analytics/skill-usage.jsonl` | 所有 skill（preamble，仅在 telemetry 开启时） | `gstack-telemetry-sync` | 用户行为遥测 |
| `sessions/$PPID` | 所有 skill（preamble touch） | preamble（统计活跃 session 数） | 轻量会话计数，2小时后自动过期 |
| `config/` | `gstack-config set` | 所有 skill（preamble） | 用户偏好持久化（proactive、telemetry、routing 等） |

### 3.3 项目根目录工件

| 工件 | 写入者 | 读取者 | 写入时机 | 用途 |
|------|-------|-------|---------|------|
| `TODOS.md` | `/ship` step 5.5（自动标记完成项）、各 review skill（用户选 A 时） | `/ship` step 3.48（范围漂移检测）、`/review` step 5.5、`/plan-eng-review` step 0 | ship 时自动 + 评审后按需 | 项目待办事项，P0-P4 优先级，包含已完成区块 |
| `VERSION` | `/ship` step 4 | 所有 skill（preamble）、`/ship`、`/land-and-deploy` | 每次 ship 时 | 语义化版本号（MAJOR.MINOR.PATCH.MICRO） |
| `CHANGELOG.md` | `/ship` step 5 | `/land-and-deploy`、发版 notes | 每次 ship 时 | 变更日志，从 diff 自动生成后追加 |
| `CLAUDE.md` | 用户 + routing 注入（preamble） | Claude Code（对话开始时） | 初始化 + skill routing 配置时 | 项目级 Claude 指令，包含 skill routing 规则 |

---

## 四、TODOS.md 完整生命周期

这是理解 gstack 协作方式的最佳切入点。

### 4.1 谁写入 TODOS.md？

```
写入者                    触发条件                              写入内容
──────────────────────────────────────────────────────────────────────
/ship step 5.5           每次 ship 自动执行                  将已完成项移入 Completed 区块
                                                              附上 vX.Y.Z (YYYY-MM-DD)

/plan-eng-review          review 完成后，逐条 AskUserQuestion  延迟工作（选 A 时写入）
/plan-ceo-review          同上                                延迟工作（选 A 时写入）
/plan-design-review       同上                                设计债务（选 A 时写入）

/qa Phase 11              QA 跑完后，发现新 bug              新 bug 条目（含复现步骤）

/cso                      发现安全问题，用户选 D              带安全标签的条目

/plan-devex-review        review 完成后，逐条 AskUserQuestion  DX 债务（选 A 时写入）

/document-release Step 7  扫描 diff 里的 TODO/FIXME 注释      有价值的延迟工作（AskUserQuestion 后）
```

**规律**：
- `/ship` 的"标记完成"是**自动的**，无需用户干预
- 其他 skill 的写入都是 **AskUserQuestion 后用户选 A** 才写入
- 从不自动删除条目，只追加或移入 Completed

### 4.2 谁读取 TODOS.md？

```
读取者                    读取时机                              用途
──────────────────────────────────────────────────────────────────────
/ship step 3.48          landing review 之前                 Scope Drift Detection：与 diff 比对
                                                              检测功能蔓延或需求缺失

/review Step 5.5         review 过程中                       TODOS cross-reference：
                                                              - 此 PR 是否关闭了某个 TODO？
                                                              - 此 PR 是否产生了新的应该变 TODO 的工作？

/plan-eng-review Step 0  scope challenge 阶段               检测 deferred 项是否 blocking 此 plan
                                                              可顺带打包相关 TODO 到此 PR
```

---

## 五、Review 体系关系图

```
                    ┌─────────────────────┐
                    │    PLAN REVIEWS      │  （编码前，可选）
                    │  ─────────────────  │
                    │  /plan-ceo-review    │  → 范围决策（expansion/hold/reduction）
                    │  /plan-eng-review    │  → 架构 + 测试规划
                    │  /plan-design-review │  → 视觉方向
                    │  /plan-devex-review  │  → 开发者体验
                    │  /autoplan           │  → 一键跑完所有 + taste gate*
                    └──────────┬──────────┘
                               │ 产生 reviews.jsonl 条目
                               ▼
                    ┌─────────────────────┐
                    │  READINESS DASHBOARD │  （/ship Step 1.4 展示）
                    │  ─────────────────  │
                    │  gstack-review-read  │  ← 读 $BRANCH-reviews.jsonl
                    │                      │
                    │  CEO Review   ✓/✗    │
                    │  Eng Review   ✓/✗    │  ← 唯一阻塞 ship 的门禁
                    │  Design       ✓/✗    │
                    │  DX Review    ✓/✗    │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │  PRE-LANDING REVIEW  │  （/ship Step 3.5，强制）
                    │  ─────────────────  │
                    │  Checklist Pass      │  → SQL、trust boundary、副作用
                    │  Specialist Dispatch │  → Greptile、Codex、安全、性能
                    │  Design Lite Check   │  → 前端变更时触发
                    │                      │
                    │  ┌─────────────────┐ │
                    │  │   Fix-First      │ │
                    │  │  AUTO-FIX        │ │ → 自动修复后 commit
                    │  │  ASK             │ │ → AskUserQuestion 逐条确认
                    │  └─────────────────┘ │
                    └──────────┬──────────┘
                               │ gstack-review-log 写入
                               ▼
                    reviews.jsonl 更新（/ship 的这次评审结果）
```

**\* taste gate**：`/autoplan` 在跑完所有评审后，会对"scope expansion"、"架构选择"等主观决策点逐一询问用户确认，而非完全自动化。两个 AI 模型意见一致也不等于自动执行（User Sovereignty 原则）。

**核心区别**：

| 维度 | Plan Reviews | Pre-landing Review |
|------|-------------|-------------------|
| 时机 | 编码前 | 代码写完、准备 merge 前 |
| 强制性 | 可选（推荐） | 强制（/ship 内置） |
| 输入 | 设计文档/计划 | `git diff` |
| 输出 | 设计决策记录 | 代码问题修复 + 结果日志 |
| 是否改代码 | 否 | 是（Fix-First） |

---

## 六、学习系统（Learnings）

### 6.1 工作机制

```
Skill 启动（preamble）
    │
    ├─► gstack-learnings-search --limit 3
    │   按 confidence DESC + recency 排序
    │   → 输出 top 3 到 skill 上下文
    │
Skill 执行
    │
    ├─► 学习发现（patterns、pitfalls、preferences）
    │
Skill 完成
    │
    └─► gstack-learnings-log '{"key":...,"insight":...,"confidence":N}'
        → 追加到 learnings.jsonl
```

### 6.2 Confidence Decay（防止陈旧知识）

```
类型          衰减规则                  原理
─────────────────────────────────────────────────────
observed      每 30 天 -1 分           代码变了，旧 pattern 可能失效
inferred      每 30 天 -1 分           AI 推断，准确性会随时间降低
user-stated   永不衰减                 用户明确陈述的始终有效
```

读取时（`gstack-learnings-search`）去重：相同 key+type 取最新版本。可通过 log 新版本来覆盖旧学习。

### 6.3 Learning 类型

| 类型 | 含义 | 示例 |
|------|------|------|
| `pattern` | 可复用的架构模式 | "异步处理适合 webhook 场景" |
| `pitfall` | 要避免的陷阱 | "webhook delivery 有竞态条件" |
| `preference` | 用户的风格偏好 | "偏好 async 而非 sync 处理" |
| `architecture` | 系统设计决策 | "refund 用 event sourcing" |
| `tool` | 工具/库洞察 | "Bun 比 Node 快 3x 用于 JSONL" |
| `operational` | 工作流程改进 | "webhook 测试比预期慢，需 mock" |

### 6.4 跨项目学习（Cross-project Learnings）

- 默认：learnings 仅在当前项目内加载
- 开启 `cross_project_learnings = true` 后：跨项目加载，但只信任 `source=user-stated` 的条目（防止 prompt injection）

---

## 七、Builder Profile（全局构建者档案）

`~/.gstack/builder-profile.jsonl` 记录用户跨项目的成长轨迹，由 `/office-hours` 写入。

### Tier 系统

| Tier | 触发条件（SESSION_COUNT） | /office-hours 的行为 |
|------|--------------------------|---------------------|
| `introduction` | 第 1 次（count=0） | 完整 3-beat 结构 + YC plea |
| `welcome_back` | 第 2-4 次（count=1-3） | 上次作业回顾 + 跳过 YC 推销 |
| `regular` | 第 5-8 次（count=4-7） | 跨 session 信号模式分析 + builder-journey.md |
| `inner_circle` | 第 9 次以上（count≥8） | 数据说话，全量 accumulated signal 摘要 |

这个系统让 AI 不会对同一个用户重复同样的入门体验——tier 越高，响应越像"老朋友"而非"新客户"。

---

## 八、Preamble：所有 skill 的标准启动序列

每个 skill 都从相同的 preamble 开始（`{{PREAMBLE}}` 模板变量展开后）。`preamble-tier` 控制注入的完整程度：

```bash
# Tier 1+ (所有 skill)
1. gstack-update-check          检测是否有新版本
2. session touch                 更新 ~/.gstack/sessions/$PPID
3. 读取 config                   proactive、telemetry、routing 等偏好

# Tier 2+
4. gstack-learnings-search       加载 top 3 学习到上下文

# Tier 3+ (大多数 skill)
5. gstack-timeline-log started   记录 skill 开始事件（后台，非阻塞）
6. telemetry log                 记录 skill 启动（如果 telemetry 开启）
7. 一次性初始化（仅首次出现）：
   - Lake intro（Boil the Lake 原则介绍）
   - Telemetry 许可请求
   - Proactive 行为设置
   - Skill routing 注入 CLAUDE.md

# Tier 4 (关键路径 skill：/review、/ship 等)
8. Vendoring 弃用警告
   Session 追踪、完整 "Boil the Lake" 规则注入
```

Tier 越高，初始化越完整，token 消耗也略多。`/review`、`/ship` 用 Tier 4，因为它们是代码入库前的最后关口。详见 [how-skills-work.md](./how-skills-work.md)。

---

## 九、/ship：研发流程的收敛点

`/ship` 是整个系统的终点，也是最重要的 skill。它的设计理念是：

**"DO IT"——不问确认，全自动，只在必要时停止。**

停止点（需用户干预）：
1. Merge conflict（无法自动解决）
2. 测试失败（且属于当前分支引入的）
3. Eval suite 失败（Step 3.25，仅在 prompt 相关文件变更时触发）
4. Coverage 低于阈值（可 override，但会要求明确确认）
5. P0 计划项未完成（必须 DONE 或显式 override）
6. ASK 类 review 发现（用户逐条决策后需 re-run /ship 重新验证）
7. Greptile comments 需要升级处理（Step 3.75，PR 已存在时才触发）
8. MINOR/MAJOR 版本升级（需用户确认）

其余全部自动化：merge、test、AUTO-FIX、version、changelog、todos、commit、push、PR。

```
/ship 输出的 PR body 包含：
├── Summary（所有变更摘要，按主题分组）
├── Test Coverage（覆盖率变化，Step 3.4 数据）
├── Pre-Landing Review（代码审查发现，自动修/用户决策）
├── Design Review（前端变更时，lite 设计检查）
├── Eval Results（prompt 相关文件变更时）
├── Greptile Review（PR 已存在时）
├── Scope Drift（范围漂移检测，Step 3.48）
├── Plan Completion（计划项完成状态，Step 3.45）
├── Verification Results（验证测试结果，Step 3.47）
└── TODOS（本次 ship 标记完成的待办项）
```

---

## 十、数据设计：为什么选择 Append-only JSONL？

gstack 的所有核心 artifact 都是追加写（append-only）的 JSONL 文件，没有中央数据库。

| 传统方案 | gstack 方案 | 优势 |
|---------|-----------|------|
| SQL 数据库 | Append-only JSONL | 无并发锁、历史完整可追溯、易于 git 版本控制 |
| 实时聚合（索引） | 读取时聚合（search-time） | 写入极快、无锁争用、容忍网络延迟 |
| 手动创建计划文件 | Skill 自动生成 artifact | 格式一致、不会遗忘 |
| 事后整理文档 | 工作时同步记录 | 实时可追溯 |

**关键洞察**：`learnings.jsonl` 的去重和衰减在**读取时**计算，而非写入时。这意味着：
- 写入永远是 `O(1)` 的 append 操作
- 读取时动态应用 confidence decay
- 用户可以通过写入新版本来"更新"旧学习，旧条目保留不删除

---

## 十一、这套方法论的本质

gstack 不是一个"工具集合"，而是一套**工作流编程语言**：

```
Skill      = 一个完整的工作流（不是零散命令）
Preamble   = 通用初始化（学习、遥测、会话、升级）
Artifact   = 工作流之间的数据通道
Review System = 多模型评审的编排逻辑
/ship      = 从代码到 PR 的不可中断编译流程
```

**五层架构（由内到外）**：

```
┌──────────────────────────────────────────────┐
│  Ethos：Boil the Lake / Search First / User Sovereignty │
├──────────────────────────────────────────────┤
│  Workflow Skills：完整的工作流 skill（不是零散命令）     │
├──────────────────────────────────────────────┤
│  Artifact System：Append-only JSONL，读取时聚合        │
├──────────────────────────────────────────────┤
│  Review System：多维评审 + Fix-First + Readiness Gate  │
├──────────────────────────────────────────────┤
│  Behavior Control：Preamble + Config + Routing         │
└──────────────────────────────────────────────┘
```

**最核心的一句话**：gstack 的设计目标是让"做完整版本"的成本和"做捷径版本"一样低——因为在 AI 辅助下，完整度的边际成本已经接近零了。
