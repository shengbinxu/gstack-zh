# gstack 运行时内部机制：Preamble 系统 + 状态存储

> 对应源码：[`scripts/resolvers/preamble.ts`](https://github.com/garrytan/gstack/blob/main/scripts/resolvers/preamble.ts) · [`bin/`](https://github.com/garrytan/gstack/tree/main/bin)
> 本文解读 gstack 的运行时机制：每个 skill 启动时做什么，状态如何在 `~/.gstack/` 中存储和流动。

---

## 1. Preamble 系统

### 1.1 核心设计原则

**Preamble 的本质是状态收集器。**

每个 skill 开头都有一段 bash block（由 `{{PREAMBLE}}` 模板变量注入），它把当前系统状态转为 Claude 能读懂的 key-value 对，然后后续 markdown 条件指令驱动 Claude 的行为。

```
bash stdout 输出              →  Claude 读取  →  markdown 条件指令触发行为
BRANCH: main
PROACTIVE: true
REPO_MODE: solo
UPGRADE_AVAILABLE 0.16 0.17
...
```

没有服务端，没有 daemon，没有运行时进程。**状态全部编码在 bash stdout 里，行为全部编码在 SKILL.md 的条件指令里。**

### 1.2 Preamble Bash 的 9 件事（按执行顺序）

```bash
# 1. 版本检查（静默，输出 "" 或 "UPGRADE_AVAILABLE old new"）
_UPD=$(gstack-update-check 2>/dev/null)
echo "$_UPD"

# 2. Session 计数（用 PPID 追踪，120min TTL）
touch ~/.gstack/sessions/"$PPID"
find ~/.gstack/sessions -mmin +120 -type f -exec rm {} +

# 3. 读用户配置
_PROACTIVE=$(gstack-config get proactive)
_SKILL_PREFIX=$(gstack-config get skill_prefix)
echo "PROACTIVE: $_PROACTIVE"

# 4. 检测当前 git 分支
_BRANCH=$(git branch --show-current)
echo "BRANCH: $_BRANCH"

# 5. Repo 模式检测（solo/collaborative，来自 gstack-repo-mode，缓存 7 天）
source <(gstack-repo-mode)
echo "REPO_MODE: $REPO_MODE"

# 6. 一次性 onboarding 标志（靠文件存在性判断）
_LAKE_SEEN=$([ -f ~/.gstack/.completeness-intro-seen ] && echo "yes" || echo "no")
_TEL_PROMPTED=$([ -f ~/.gstack/.telemetry-prompted ] && echo "yes" || echo "no")
_PROACTIVE_PROMPTED=$([ -f ~/.gstack/.proactive-prompted ] && echo "yes" || echo "no")
echo "LAKE_INTRO: $_LAKE_SEEN"

# 7. Telemetry（本地 JSONL 追加 + 可选远程上报）
echo '{"skill":"ship","ts":"...","repo":"..."}' >> ~/.gstack/analytics/skill-usage.jsonl

# 8. Learnings 注入（项目级记忆，>5 条时自动语义搜索注入最相关 3 条）
eval "$(gstack-slug)"
_LEARN_FILE=~/.gstack/projects/$SLUG/learnings.jsonl
gstack-learnings-search --limit 3   # 注入到 stdout，Claude 读取

# 9. 环境特征检测
_HAS_ROUTING=$(grep -q "## Skill routing" CLAUDE.md && echo "yes" || echo "no")
_VENDORED=$([ -d ".claude/skills/gstack" ] && echo "yes" || echo "no")
[ -n "$OPENCLAW_SESSION" ] && echo "SPAWNED_SESSION: true"
```

### 1.3 Bash 输出 → Claude 行为映射

| stdout 输出 | Claude 触发的行为 |
|------------|-----------------|
| `UPGRADE_AVAILABLE 0.16 0.17` | 读 `gstack-upgrade/SKILL.md`，走升级流程 |
| `BRANCH: main` | 后续每个 AskUserQuestion 都从此分支名开始 |
| `PROACTIVE: false` | 不主动建议 /skill，只响应用户显式调用 |
| `REPO_MODE: solo` | 发现问题时主动修复，不只是 flag |
| `LAKE_INTRO: no` | 先介绍 Boil the Lake 原则（终身只一次） |
| `TEL_PROMPTED: no` | 询问遥测偏好（终身只一次） |
| `PROACTIVE_PROMPTED: no` | 询问主动模式偏好（终身只一次） |
| `HAS_ROUTING: no` | 建议写入 CLAUDE.md routing 规则（每 project 一次） |
| `VENDORED_GSTACK: yes` | 提示 vendoring 已废弃（每 project 一次） |
| `SPAWNED_SESSION: true` | 完全自主模式，跳过所有交互提示 |
| `LEARNINGS: 12 entries...` | 后续决策参考注入的项目经验 |

### 1.4 一次性 Onboarding 的实现

没有数据库，靠文件存在性：

```
~/.gstack/.completeness-intro-seen   → Boil the Lake 原则已介绍
~/.gstack/.telemetry-prompted        → 遥测已问过
~/.gstack/.proactive-prompted        → 主动模式已问过
~/.gstack/.vendoring-warned-$SLUG    → 当前 project 已警告过
```

显示一次后 `touch` 对应文件，下次 preamble 检查文件存在，条件指令跳过。简单、可靠、可手动 `rm` 重置。

### 1.5 SPAWNED_SESSION：AI 编排模式

```bash
[ -n "$OPENCLAW_SESSION" ] && echo "SPAWNED_SESSION: true"
```

gstack 支持被 AI orchestrator（如 OpenClaw）调用。检测到 `SPAWNED_SESSION: true` 时，Claude 自动跳过所有 AskUserQuestion，auto-choose 推荐选项，最后输出结构化完成报告。**同一套 SKILL.md，人类交互模式和 agent 自动化模式都能跑。**

### 1.6 preamble-tier：多级 Preamble

`preamble.ts` 实现的 preamble 是"完整版"（tier 4）。通过 frontmatter `preamble-tier` 字段控制注入层级：

| tier | 包含内容 |
|------|---------|
| 1 | 最简：仅 update check + branch 检测 |
| 2 | 加 session 追踪 + proactive 配置 |
| 3 | 加 learnings 注入 + repo mode |
| 4 | 完整：加 onboarding 引导 + telemetry + vendoring 检测 |

简单 skill（如 `/careful`）用 tier 1，重型 skill（如 `/ship`、`/review`）用 tier 4。

---

## 2. `~/.gstack/` 状态系统

### 2.1 完整目录结构

```
~/.gstack/
├── config.yaml              # 全局用户配置
│   # telemetry: community
│   # proactive: true
│   # auto_upgrade: true
│   # skill_prefix: false
│   # cross_project_learnings: true
├── installation-id          # 稳定设备 ID（遥测用，不含个人信息）
├── just-upgraded-from       # 升级后残留，下次 preamble 显示 "just updated!"
├── slug-cache/              # project slug 缓存（绝对路径 → slug 映射）
├── sessions/                # 活跃 session 追踪（touch $PPID，120min TTL）
├── analytics/
│   └── skill-usage.jsonl    # 本地 + 遥测双路日志
└── projects/
    └── {slug}/              # 每个 project 一个目录
        ├── repo-mode.json       # 协作模式（solo/collaborative，7天缓存）
        ├── timeline.jsonl       # skill 启动/完成事件（纯本地）
        ├── learnings.jsonl      # 项目级经验（append-only）
        ├── {branch}-reviews.jsonl  # review 结果（per branch）
        ├── ceo-plans/           # 私有 CEO plan 文档
        │   └── {date}-{slug}.md
        ├── designs/             # 私有设计 artifacts
        └── checkpoints/         # 跨 session 进度存档
```

### 2.2 SLUG 派生机制

SLUG 是 project 的全局唯一 ID，从 git remote URL 计算，跨 session 稳定：

```bash
# https://github.com/shengbinxu/gstack-zh.git
#    ↓ sed 提取 "owner/repo"
# shengbinxu/gstack-zh
#    ↓ tr '/' '-'
# shengbinxu-gstack-zh  ← SLUG

REMOTE_URL=$(git remote get-url origin 2>/dev/null)
SLUG=$(echo "$REMOTE_URL" \
  | sed 's|.*[:/]\([^/]*/[^/]*\)\.git$|\1|;s|.*[:/]\([^/]*/[^/]*\)$|\1|' \
  | tr '/' '-')
```

结果缓存在 `~/.gstack/slug-cache/`（key = 当前绝对路径 encode）。换分支不影响 slug，换 clone 位置需要重新计算但结果相同。

### 2.3 Learnings 系统

#### 写入（append-only）

```jsonc
{
  "skill": "review",
  "type": "pitfall",          // pattern|pitfall|preference|architecture|tool|operational
  "key": "n-plus-one",        // 字母数字+连字符，用于去重
  "insight": "N+1 queries in associations always miss prod load test",
  "confidence": 8,            // 1-10
  "source": "observed",       // observed|user-stated|inferred|cross-model
  "ts": "2026-04-14T10:00:00Z"
}
```

写入时经过 Bun 脚本验证：type/source 枚举检查、key 格式限制、confidence 范围，以及 **insight 字段的 prompt injection 过滤**（strip 掉"ignore all previous instructions"等指令型 pattern）。

#### 读取（去重 + 衰减）

`gstack-learnings-search` 读 JSONL：
1. 按 `key+type` 去重（latest winner）
2. 置信度随时间衰减
3. 关键词/类型过滤
4. 可选 `--cross-project`（读其他 project 的 learnings）

**设计意图**：调试 Next.js hydration 问题时存下来的 learning，在本周 /ship 时如果又遇到类似 pattern，会自动浮现到 preamble 里。记忆随项目经验增长，不需要人工整理。

### 2.4 repo-mode.json：协作模式检测

```bash
# 90 天窗口，统计 author commit 占比
git log --since="90 days ago" --format="%ae" | sort | uniq -c | sort -rn

# top author >= 80% → solo，否则 collaborative
```

```json
{"mode": "solo", "top_pct": 83, "authors": 2, "total": 18, "computed": "2026-04-14T15:49:12Z"}
```

缓存 7 天。影响：pre-existing 测试失败时，solo 模式推荐"立即修复"（AI 修比人快），collaborative 模式推荐"blame + 创建 issue 分配给责任人"。

### 2.5 timeline.jsonl：skill 执行历史

```jsonl
{"skill":"plan-eng-review","event":"started","branch":"main","session":"6978-1776181752","ts":"..."}
{"skill":"plan-eng-review","event":"completed","branch":"main","outcome":"abort","duration_s":"710","session":"...","ts":"..."}
```

preamble 里**后台异步写**（`& 异步`），不阻塞 skill 启动。Context Recovery 功能读 timeline，生成 "Welcome back to {branch}. Last session: /{skill} ({outcome})." 的问候。

### 2.6 Artifact 存储路径

| Artifact | 路径 | 性质 |
|---------|------|------|
| CEO Plan（设计文档草稿） | `~/.gstack/projects/$SLUG/ceo-plans/{date}-{slug}.md` | 私有，不提交 |
| 设计 Artifacts（design-consultation） | `~/.gstack/projects/$SLUG/designs/` | 私有，不提交 |
| 促进发布的设计文档 | `docs/designs/{FEATURE}.md`（repo 内） | 团队可见，需 promote |
| eng review 测试计划 | `~/.gstack/projects/$SLUG/{user}-{branch}-eng-review-test-plan-*.md` | 私有 |
| Checkpoints | `~/.gstack/projects/$SLUG/checkpoints/` | 私有 |

**重要区分**：设计文档默认写入私有 `~/.gstack/` 目录，不提交。只有手动执行 "promote" 操作后，才复制到 repo 的 `docs/designs/` 让团队看到。

### 2.7 为什么用 JSONL 而不是 SQLite

- **append-only 写入**：bash 和 Bun 都能处理，并发安全
- **可直接 `tail -f` 观测**：调试时可见
- **git 可 diff**：`.gstack` 目录用 git 同步时（如 gstack-backup）历史可查
- **无 schema migration 烦恼**：新字段向后兼容，旧记录忽略未知字段

---

## 3. 设计总结

| 系统 | 存储位置 | 生命周期 | 用途 |
|------|---------|---------|------|
| Preamble 输出 | bash stdout（临时） | 单次 skill 执行 | 状态 → 行为映射 |
| Learnings | `~/.gstack/projects/$SLUG/learnings.jsonl` | 永久（跨 session） | 项目级经验记忆 |
| Timeline | `~/.gstack/projects/$SLUG/timeline.jsonl` | 永久（历史审计） | Context Recovery |
| Reviews | `~/.gstack/projects/$SLUG/{branch}-reviews.jsonl` | Per-branch | /ship 看板 |
| Onboarding 标志 | `~/.gstack/.*-prompted` 文件 | 永久（终身一次） | 避免重复引导 |
| Session 追踪 | `~/.gstack/sessions/$PPID` | 120min TTL | 并发 session 计数 |
