# 构建公司版 gstack：核心决策指南

> 本文基于对 gstack 源码的完整分析（Phase 1-6），为在公司业务中构建类似 AI 工程师工具库提供决策参考。
> 不是实现教程，是"在哪里花时间"的判断。

---

## 1. gstack 的本质（一句话）

**gstack 是用 markdown 写的软件，Claude 的推理能力做运行时，`~/.gstack/` 目录做数据库。**

没有框架，没有服务器，没有部署。40 个技能 = 40 个精心设计的 markdown 文件，加一套 `~/.gstack/` 目录做状态存储。

这既是优势（无需部署，用自然语言描述复杂流程），也是边界（Claude context window 限制了 skill 能有多长）。

---

## 2. 直接复用的架构决策

这些设计已被 gstack 验证，不要重新发明：

### 2.1 SKILL.md 格式

```yaml
---
name: company-ship
description: |
  Ship workflow: run tests, review diff, create PR.
  Invoke when user says "ship", "deploy", "push", "create PR".
allowed-tools: [Bash, Read, Write, Edit, AskUserQuestion]
---

## Preamble (run first)
[bash block: 状态收集]

## Step 1: ...
[流程指令]
```

`allowed-tools` 是安全边界，限制 skill 能操作的工具范围。每个 skill 都写清楚触发条件（description），供 CLAUDE.md routing 规则匹配。

### 2.2 在 CLAUDE.md 加 routing 规则

```markdown
## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.

Key routing rules:
- 代码审查、check my diff → invoke review
- ship/deploy/push/PR → invoke ship
- bug/报错/为什么挂了 → invoke investigate
```

**关键**：必须在 SKILL.md 开头明确声明"逐步执行，不跳过，不重排"。没有这句话，Claude 会把 skill 内容"理解后自行发挥"，而不是严格执行。差别很大。

```markdown
## 执行规则

你在执行 /company-ship 工作流。这是非交互式全自动流程。
按步骤执行每一步，不跳过，不重新排序，不简化。
```

### 2.3 `~/.{company}/` 状态目录 + JSONL

```
~/.{company}/
├── config.yaml
└── projects/{slug}/
    ├── learnings.jsonl     # 项目级经验
    ├── timeline.jsonl      # skill 执行历史
    └── {branch}-reviews.jsonl  # review 缓存
```

Slug 从 git remote URL 派生：`owner/repo` → `owner-repo`。跨 session 稳定，跨机器一致（只要 remote 相同）。

### 2.4 Learnings 系统

Append-only JSONL + key+type 去重。每次 skill 结束前反思：

```bash
# 这次调试发现了什么规律？
company-learnings-log '{"skill":"ship","type":"pitfall","key":"migration-order",
  "insight":"数据库 migration 必须在服务启动前执行，否则请求会打到旧 schema",
  "confidence":9,"source":"observed"}'
```

preamble 里自动注入 top 3 relevant learnings。经验随项目积累，下次遇到同类问题自动提示。

**注意**：写入时必须过滤 prompt injection（insight 字段里的指令型文本）。

### 2.5 Preamble = 状态收集器模式

```bash
# preamble bash 输出 key-value
echo "BRANCH: $(git branch --show-current)"
echo "REPO_MODE: $(company-repo-mode)"
echo "ENV: $(company-env-detect)"   # dev/staging/prod

# 后续 markdown 条件指令消费
# If REPO_MODE is "solo": ...
# If ENV is "prod": ...
```

把复杂的"根据环境决定行为"逻辑，编码为 prompt 条件指令而非代码分支。

---

## 3. 必须重新设计的部分

### 3.1 Preamble 环境检测（最大适配成本）

gstack preamble 检测的是 GitHub/GitLab、npm/bun/cargo。你的公司可能是：

| gstack 检测 | 公司替换 |
|------------|---------|
| `gh pr view` | `glab mr view` 或内部 git API |
| `bin/test-lane` | 公司的测试命令（`make test`、`./scripts/test.sh`） |
| `git remote get-url origin` | 可能需要处理 monorepo subdir |
| npm/bun/cargo | 公司包管理器 |

**这是 preamble bash 里所有"检测环境"的命令**，全部换成公司实际工具。这是适配成本的主体，通常需要 1-2 天。

### 3.2 /ship 的 Gate 条件

从最简单的开始，只保留真正必要的 gate：

**最小 v1 gate 集（3 个）：**
1. 不在 base branch
2. merge base + 测试通过
3. 基本 eng review（code smell 检查，可以就是让 Claude 读 diff）

拿掉 eval suite（没有 LLM prompt 文件）、Greptile（换成内部工具或暂时不用）、coverage audit（先不强制）、plan completion（先不接 plan 系统）。

**按需加 gate 的顺序：**
1. coverage audit（测试覆盖率）
2. 内部安全扫描 gate
3. eval suite（如果有 LLM prompt 文件）
4. 合规检查（如果有法务/安全要求）

### 3.3 Learnings Type Taxonomy

gstack 定义了 6 种 type：`pattern | pitfall | preference | architecture | tool | operational`

公司可能需要：

```
pattern      → 通用，保留
pitfall      → 通用，保留
preference   → 通用，保留
architecture → 通用，保留
tool         → 通用，保留
operational  → 通用，保留
security     → 新增：安全相关发现（SQL injection、权限漏洞等）
compliance   → 新增：合规注意点（数据处理、日志脱敏等）
```

**先定好再实施。** learnings 是跨 session 积累的，后期改 schema 需要迁移脚本。

---

## 4. 分发策略

| 方案 | 优点 | 缺点 | 适合阶段 |
|------|------|------|---------|
| **A: CLAUDE.md 内嵌** | 零安装，立刻生效 | 难以统一升级，每个 repo 单独维护 | 验证价值阶段 |
| **B: 内部 git repo + setup 脚本** | 集中管理，version 控制，团队统一 | 需要维护 repo 和 setup 流程 | 成熟推广阶段 |
| **C: npm/pip 包** | 有 semver，依赖锁定 | 需要发布流程，增加维护负担 | 规模化阶段 |

**推荐路径**：A → B（当 3 个以上人在用时） → 视规模决定 C

### 方案 B 的最简 setup 脚本

```bash
#!/usr/bin/env bash
# setup — 链接 skills 到 ~/.claude/skills/

SKILL_DIR="$HOME/.claude/skills"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$SKILL_DIR"

for skill in ship review investigate checkpoint; do
  mkdir -p "$SKILL_DIR/company-$skill"
  ln -sf "$REPO_DIR/$skill/SKILL.md" "$SKILL_DIR/company-$skill/SKILL.md"
done

echo "Done. Skills linked to ~/.claude/skills/company-*"
```

---

## 5. 起步 Skill 集

不要一开始就做 40 个 skill。按价值/复杂度排序，逐步实施：

| Skill | 用户价值 | 实现复杂度 | 推荐顺序 |
|-------|---------|-----------|---------|
| `/ship`（简化版） | 最高（每次都用） | 高 | 2（先做 v1 再迭代） |
| `/review` | 高（能发现 bug） | 中 | 3 |
| `/investigate` | 高（调 bug 省时） | 低 | 1（最简单，先做） |
| `/checkpoint` | 中（跨 session 续作） | 低 | 4 |

### 简化版 `/ship`（v1，5 步）

```markdown
---
name: company-ship
description: Ship: run tests, review, create PR. Invoke when user says "ship".
allowed-tools: [Bash, Read, Write, Edit, AskUserQuestion]
---

按步骤执行，不跳过，不简化。

## Step 1: 检查分支
git branch --show-current
如果在 main/master，ABORT：必须在 feature branch 上 ship。

## Step 2: Merge base branch
git fetch origin main && git merge origin/main --no-edit

## Step 3: 跑测试
[公司测试命令]
测试失败 → STOP。

## Step 4: 基本 Code Review
读 git diff origin/main...HEAD，找明显问题（N+1、硬编码密钥、未处理 error）。
Auto-fixable 问题直接修，ASK 级别问题用 AskUserQuestion。

## Step 5: 创建 PR
git add -A && git commit -m "..." && git push -u origin HEAD
gh pr create --title "..." --body "..."
```

---

## 6. 最重要的一个设计判断

**Skill 是"可执行指令"还是"参考文档"？**

如果是参考文档，Claude 会理解内容然后自行发挥，每次执行结果不一致。

如果是可执行指令，Claude 会严格按步骤执行，结果可复现、可预期。

**gstack 选择了"可执行指令"。** 每个 skill 开头都有明确声明，routing 规则也要求"第一个动作就是调用 skill，不先直接回答"。

你的公司库也必须做同样的决定，并在两个地方声明清楚：
1. 每个 SKILL.md 开头
2. CLAUDE.md 的 routing 规则

---

## 7. 主要工作量在哪里

这不是框架开发，是 **prompt engineering at scale**。

| 工作项 | 技术难度 | 时间 |
|-------|---------|------|
| 把工程规范翻译为 markdown 指令 | 低（写作） | 最多 |
| 替换 preamble 里的公司工具链命令 | 低（bash） | 中 |
| 定义 gate 条件和 stop/continue 逻辑 | 中（判断） | 中 |
| 实现 learnings/timeline bin 脚本 | 中（bash+bun） | 少 |
| setup 脚本 + 分发机制 | 低 | 少 |

**主要工作**是把隐性的工程规范（"我们公司怎么做 code review"、"测试失败时怎么处理"）变成 Claude 可以严格执行的 markdown 指令。这需要对自己公司的工程实践有清晰的认识，然后用自然语言精确描述。
