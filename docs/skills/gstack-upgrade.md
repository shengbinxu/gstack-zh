# `/gstack-upgrade` 技能逐段中英对照注解

> 对应源文件：[`gstack-upgrade/SKILL.md`](https://github.com/garrytan/gstack/blob/main/gstack-upgrade/SKILL.md)（275 行，自动从 `SKILL.md.tmpl` 生成）
> 本文**逐段**保留英文原文关键片段，加入中文翻译和设计原理解读。

---

## 一、Frontmatter（元数据区）

```yaml
---
name: gstack-upgrade
version: 1.1.0
description: |
  Upgrade gstack to the latest version. Detects global vs vendored install,
  runs the upgrade, and shows what's new. Use when asked to "upgrade gstack",
  "update gstack", or "get latest version".
  Voice triggers: "upgrade the tools", "update the tools", "gee stack upgrade", "g stack upgrade".
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---
```

**中文解读**：

| 字段 | 值 | 含义 |
|------|-----|------|
| `name` | `gstack-upgrade` | 独立技能名，也是所有 preamble 引用的内联升级入口 |
| `version` | `1.1.0` | 与 gstack 主版本同步 |
| `allowed-tools` | Bash + Read + Write + AskUserQuestion | 需要写文件（snooze 状态）和交互提问 |

**与其他技能的关键差异**：

| 技能 | 有 Write 吗？ | 有 Edit 吗？ |
|------|--------------|-------------|
| `plan-eng-review` | ✗ | ✗ |
| `gstack-upgrade` | **✓** | ✗ |
| `qa` | ✗ | **✓** |

`gstack-upgrade` 需要 `Write` 的原因：需要写 snooze 状态文件（`~/.gstack/update-snoozed`）
和升级完成标记（`~/.gstack/just-upgraded-from`）。但不需要 `Edit`——这些都是全新写入的文件。

> **语音触发别名**：`"upgrade the tools"`, `"update the tools"`, `"gee stack upgrade"`, `"g stack upgrade"`
> 这些是语音转文字场景的容错设计，避免用户说 "gstack" 被识别错误时错过触发。

---

## 二、两种触发方式

`gstack-upgrade` 有两种完全不同的调用路径：

```
┌─────────────────────────────────────────────────────────────────────┐
│                    /gstack-upgrade 触发方式                          │
├────────────────────────────┬────────────────────────────────────────┤
│   内联升级（Inline Flow）   │      独立调用（Standalone）             │
├────────────────────────────┼────────────────────────────────────────┤
│  触发：任意技能 Preamble    │  触发：用户显式说 /gstack-upgrade        │
│  检测到 UPGRADE_AVAILABLE  │                                        │
│                            │                                        │
│  → 读取此 SKILL.md          │  → 强制绕过缓存检查最新版本              │
│  → 执行 "Inline upgrade     │  → 若有更新：执行 Steps 2-6            │
│     flow" 部分              │  → 若已最新：检查本地 vendored 副本     │
│  → 升级完成后继续原技能      │  → 报告状态，不继续其他技能              │
└────────────────────────────┴────────────────────────────────────────┘
```

> **设计原理**：把升级逻辑集中在一个技能文件里，而不是分散在每个技能的 Preamble 中。
> 任何技能检测到需要升级时，只需 `read gstack-upgrade/SKILL.md` 并执行"Inline upgrade flow"。
> 这是 DRY 原则在 AI Skill 层的体现。

---

## 三、Inline 升级流程（由 Preamble 触发）

所有技能的 Preamble 包含以下检测：

```bash
_UPD=$(~/.claude/skills/gstack/bin/gstack-update-check 2>/dev/null || ...)
[ -n "$_UPD" ] && echo "$_UPD" || true
```

当输出包含 `UPGRADE_AVAILABLE <old> <new>` 时，触发 Inline 升级流程（共 7 步）。

### Step 1：询问用户（或自动升级）

> **原文（第 28-75 行）**：
> ```bash
> _AUTO=""
> [ "${GSTACK_AUTO_UPGRADE:-}" = "1" ] && _AUTO="true"
> [ -z "$_AUTO" ] && _AUTO=$(~/.claude/skills/gstack/bin/gstack-config get auto_upgrade 2>/dev/null || true)
> echo "AUTO_UPGRADE=$_AUTO"
> ```

**中文**：检查是否启用了自动升级（两种来源，按优先级）：

| 优先级 | 来源 | 方式 |
|--------|------|------|
| 高 | 环境变量 `GSTACK_AUTO_UPGRADE=1` | CI/CD 或脚本场景 |
| 低 | `~/.gstack/config.yaml` 中的 `auto_upgrade: true` | 用户偏好设置 |

**四种用户选项**：

```
gstack v{new} is available (you're on v{old}). Upgrade now?

A) Yes, upgrade now
B) Always keep me up to date
C) Not now
D) Never ask again
```

| 选项 | 行为 |
|------|------|
| A：Yes | 立即执行 Step 2-6 |
| B：Always | 写入 `auto_upgrade=true` 配置，然后执行 Step 2-6 |
| C：Not now | 写 snooze 状态，继续当前技能，**不再提醒** |
| D：Never | 写入 `update_check=false`，永久关闭更新检查 |

**Auto-upgrade 失败恢复**：

> **原文**：
> "If `./setup` fails during auto-upgrade, restore from backup (`.bak` directory) and warn the user:
> 'Auto-upgrade failed — restored previous version. Run `/gstack-upgrade` manually to retry.'"

自动升级失败时：
1. 从 `$INSTALL_DIR.bak` 恢复
2. 告知用户手动运行 `/gstack-upgrade` 重试

### Step 2：检测安装类型

> **原文（第 80-102 行）**：
> ```bash
> if [ -d "$HOME/.claude/skills/gstack/.git" ]; then
>   INSTALL_TYPE="global-git"
>   INSTALL_DIR="$HOME/.claude/skills/gstack"
> elif [ -d "$HOME/.gstack/repos/gstack/.git" ]; then
>   INSTALL_TYPE="global-git"
>   INSTALL_DIR="$HOME/.gstack/repos/gstack"
> elif [ -d ".claude/skills/gstack/.git" ]; then
>   INSTALL_TYPE="local-git"
>   INSTALL_DIR=".claude/skills/gstack"
> elif [ -d ".agents/skills/gstack/.git" ]; then
>   INSTALL_TYPE="local-git"
>   INSTALL_DIR=".agents/skills/gstack"
> elif [ -d ".claude/skills/gstack" ]; then
>   INSTALL_TYPE="vendored"
>   INSTALL_DIR=".claude/skills/gstack"
> elif [ -d "$HOME/.claude/skills/gstack" ]; then
>   INSTALL_TYPE="vendored-global"
>   INSTALL_DIR="$HOME/.claude/skills/gstack"
> else
>   echo "ERROR: gstack not found"
>   exit 1
> fi
> ```

**中文**：安装类型检测逻辑（按优先级从高到低）：

```
检测顺序流程图
──────────────────────────────────────────────────────────
① ~/.claude/skills/gstack/.git 存在？
     是 → INSTALL_TYPE=global-git（全局 git 安装）

② ~/.gstack/repos/gstack/.git 存在？
     是 → INSTALL_TYPE=global-git（备用全局路径）

③ .claude/skills/gstack/.git 存在（相对路径）？
     是 → INSTALL_TYPE=local-git（项目本地 git 安装）

④ .agents/skills/gstack/.git 存在？
     是 → INSTALL_TYPE=local-git（agents 目录）

⑤ .claude/skills/gstack 目录存在（无 .git）？
     是 → INSTALL_TYPE=vendored（项目本地 vendored 副本）

⑥ ~/.claude/skills/gstack 目录存在（无 .git）？
     是 → INSTALL_TYPE=vendored-global（全局 vendored 副本）

⑦ 以上都不满足？
     → ERROR: gstack not found
──────────────────────────────────────────────────────────
```

**四种安装类型对比**：

| 类型 | 有 .git | 位置 | 升级方式 | 推荐程度 |
|------|---------|------|----------|----------|
| `global-git` | ✓ | `~/.claude/skills/gstack/` | `git pull + ./setup` | ⭐⭐⭐ 最佳 |
| `local-git` | ✓ | `.claude/skills/gstack/` | `git pull + ./setup` | ⭐⭐ 可以 |
| `vendored` | ✗ | `.claude/skills/gstack/` | `git clone + 覆盖` | ⭐ 已弃用 |
| `vendored-global` | ✗ | `~/.claude/skills/gstack/` | `git clone + 覆盖` | ⭐ 需迁移 |

### Step 3：保存旧版本号

```bash
OLD_VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "unknown")
```

**中文**：升级前记录旧版本，用于：
1. Step 4.75 判断哪些迁移脚本需要运行
2. Step 6 的 "What's New" 展示（从旧版到新版的变更列表）

### Step 4：执行升级

> **原文（第 119-138 行）**：

**Git 安装升级**（global-git / local-git）：

```bash
cd "$INSTALL_DIR"
STASH_OUTPUT=$(git stash 2>&1)
git fetch origin
git reset --hard origin/main
./setup
```

**中文**：
- `git stash`：保护用户可能存在的本地修改（会在升级后提示 `git stash pop`）
- `git reset --hard origin/main`：强制与远端 main 同步（确保干净状态）
- `./setup`：运行 gstack 的安装脚本（重新构建 browse 二进制等）

> ⚠️ **注意**：使用 `git reset --hard` 而非 `git pull`，目的是处理 rebase 场景——
> 如果远端有 force push 或 rebase，`pull` 可能失败，`reset --hard` 始终成功。

**Vendored 安装升级**（vendored / vendored-global）：

```bash
PARENT=$(dirname "$INSTALL_DIR")
TMP_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/garrytan/gstack.git "$TMP_DIR/gstack"
mv "$INSTALL_DIR" "$INSTALL_DIR.bak"
mv "$TMP_DIR/gstack" "$INSTALL_DIR"
cd "$INSTALL_DIR" && ./setup
rm -rf "$INSTALL_DIR.bak" "$TMP_DIR"
```

**中文**：
- `--depth 1`：浅克隆，只拉取最新提交，节省时间和带宽
- `mv $INSTALL_DIR $INSTALL_DIR.bak`：在原目录被覆盖前备份（失败时可恢复）
- 备份成功后移入新版，运行 `./setup`，成功则删除备份

### Step 4.5：处理本地 Vendored 副本

> **原文（第 142-186 行）**：
> ```bash
> _ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
> LOCAL_GSTACK=""
> if [ -n "$_ROOT" ] && [ -d "$_ROOT/.claude/skills/gstack" ]; then
>   _RESOLVED_LOCAL=$(cd "$_ROOT/.claude/skills/gstack" && pwd -P)
>   _RESOLVED_PRIMARY=$(cd "$INSTALL_DIR" && pwd -P)
>   if [ "$_RESOLVED_LOCAL" != "$_RESOLVED_PRIMARY" ]; then
>     LOCAL_GSTACK="$_ROOT/.claude/skills/gstack"
>   fi
> fi
> _TEAM_MODE=$(~/.claude/skills/gstack/bin/gstack-config get team_mode 2>/dev/null || echo "false")
> ```

**中文**：此步骤处理"主安装 + 项目本地副本"并存的情况：

```
场景一：team_mode=true
    LOCAL_GSTACK 非空
         │
         ▼
    删除本地 vendored 副本（git rm 移出版本控制 + rm -rf 删文件）
    写入 .gitignore（防止重新提交）
    → 告知用户 "团队模式启用，全局安装是唯一来源"

场景二：team_mode=false（非团队模式）
    LOCAL_GSTACK 非空
         │
         ▼
    将主安装复制到本地副本（覆盖更新）
    rm -rf .git（vendored 副本不需要 git 历史）
    → 告知用户 "本地副本已同步，可以 commit"
```

**关键检测**：用 `pwd -P`（resolve symlinks）比较两个路径，
排除"本地路径其实就是主路径的 symlink"的情况，避免误操作。

### Step 4.75：运行版本迁移脚本

> **原文（第 196-212 行）**：
> ```bash
> MIGRATIONS_DIR="$INSTALL_DIR/gstack-upgrade/migrations"
> if [ -d "$MIGRATIONS_DIR" ]; then
>   for migration in $(find "$MIGRATIONS_DIR" -maxdepth 1 -name 'v*.sh' | sort -V); do
>     m_ver="$(basename "$migration" .sh | sed 's/^v//')"
>     if [ "$OLD_VERSION" != "unknown" ] && \
>        [ "$(printf '%s\n%s' "$OLD_VERSION" "$m_ver" | sort -V | head -1)" = "$OLD_VERSION" ] && \
>        [ "$OLD_VERSION" != "$m_ver" ]; then
>       echo "Running migration $m_ver..."
>       bash "$migration" || echo "  Warning: migration $m_ver had errors (non-fatal)"
>     fi
>   done
> fi
> ```

**中文**：迁移脚本机制：

```
gstack-upgrade/migrations/
├── v1.0.5.sh    # 从 v1.0.5 及之前版本升级时运行
├── v1.1.0.sh    # 从 v1.0.x 升级到 v1.1.0 时运行
└── v1.2.0.sh    # 未来版本
```

**运行条件判断逻辑**：
```
m_ver = 迁移脚本版本（如 1.1.0）
OLD_VERSION = 升级前的版本（如 1.0.5）

条件：OLD_VERSION < m_ver（旧版本比迁移脚本版本小）
方法：用 sort -V（版本号语义排序），取最小的，如果最小的是 OLD_VERSION，说明满足条件
```

| OLD_VERSION | m_ver | sort -V head -1 | 运行？ |
|-------------|-------|-----------------|--------|
| 1.0.5 | 1.1.0 | 1.0.5 | ✓ 运行 |
| 1.1.0 | 1.1.0 | 1.1.0（相等）| ✗ 跳过 |
| 1.2.0 | 1.1.0 | 1.1.0 | ✗ 跳过（已比迁移版本新）|

**设计特点**：
- 迁移脚本是**幂等的** bash 脚本（可重复运行，结果不变）
- 失败是**非致命的**（只打印警告，不中断升级）
- 目的：处理 `./setup` 无法覆盖的状态变更（配置文件格式、废弃目录清理等）

### Step 5：写入完成标记 + 清除缓存

```bash
mkdir -p ~/.gstack
echo "$OLD_VERSION" > ~/.gstack/just-upgraded-from
rm -f ~/.gstack/last-update-check
rm -f ~/.gstack/update-snoozed
```

**中文**：
- `just-upgraded-from`：记录升级前版本，供下次 Preamble 检测（输出 `JUST_UPGRADED <from> <to>`）
- `last-update-check`：删除更新检查缓存，确保下次立即检查（而非等待缓存过期）
- `update-snoozed`：清除 snooze 状态（已升级，不需要再提醒）

### Step 6：展示 What's New

> **原文（第 223-237 行）**：
> ```
> Read `$INSTALL_DIR/CHANGELOG.md`. Find all version entries between the old version
> and the new version. Summarize as 5-7 bullets grouped by theme. Don't overwhelm —
> focus on user-facing changes. Skip internal refactors unless significant.
>
> Format:
> gstack v{new} — upgraded from v{old}!
>
> What's new:
> - [bullet 1]
> - ...
>
> Happy shipping!
> ```

**中文**：展示格式规范：
- 读取 `CHANGELOG.md`，找到 `OLD_VERSION` 到 `NEW_VERSION` 之间的所有变更条目
- 按主题分组整理为 5-7 条要点
- 聚焦**用户可感知的变化**，跳过内部重构（除非影响重大）
- 结束语：`Happy shipping!`（gstack 的品牌语）

**示例输出**：
```
gstack v1.2.0 — upgraded from v1.0.5!

What's new:
- /qa now generates annotated screenshots automatically for every bug found
- /investigate has a new root-cause hypothesis phase before attempting fixes
- snapshot -C flag captures cursor-interactive divs (dropdowns, custom menus)
- gstack-learnings now auto-loads project context at the start of each session
- /design-review can now diff before/after states with pixel-level comparison

Happy shipping!
```

### Step 7：继续原始任务

> **原文**：
> "After showing What's New, continue with whatever skill the user originally invoked.
> The upgrade is done — no further action needed."

**中文**：升级完成后，**继续执行触发升级检测的那个技能**。
升级是插入到原始工作流中的，完成后无缝恢复。

---

## 四、Snooze 机制（推迟升级提醒）

> **原文（第 50-68 行）**：
> ```bash
> _SNOOZE_FILE=~/.gstack/update-snoozed
> _CUR_LEVEL=0
> if [ -f "$_SNOOZE_FILE" ]; then
>   _SNOOZED_VER=$(awk '{print $1}' "$_SNOOZE_FILE")
>   if [ "$_SNOOZED_VER" = "$_REMOTE_VER" ]; then
>     _CUR_LEVEL=$(awk '{print $2}' "$_SNOOZE_FILE")
>   fi
> fi
> _NEW_LEVEL=$((_CUR_LEVEL + 1))
> [ "$_NEW_LEVEL" -gt 3 ] && _NEW_LEVEL=3
> echo "$_REMOTE_VER $_NEW_LEVEL $(date +%s)" > "$_SNOOZE_FILE"
> ```

**中文**：Snooze 采用**递增退避策略**：

| Snooze 次数 | Level | 再次提醒间隔 |
|-------------|-------|-------------|
| 第 1 次 | 1 | 24 小时 |
| 第 2 次 | 2 | 48 小时 |
| 第 3 次及以上 | 3（上限）| 1 周 |

**Snooze 文件格式**：`~/.gstack/update-snoozed`
```
1.2.0 2 1704067200
↑版本  ↑level ↑时间戳(Unix)
```

**版本绑定**：Snooze 只对特定版本生效。如果远端发布了更新版本（如从 snooze v1.2.0 时发布了 v1.2.1），则重新开始提醒。

**退出 Snooze 的方式**：
- 手动运行 `/gstack-upgrade`（强制检查）
- 等待 snooze 期满
- 升级完成后自动清除（Step 5 中 `rm -f ~/.gstack/update-snoozed`）

---

## 五、独立调用（Standalone Usage）

> **原文（第 245-275 行）**：
> ```
> When invoked directly as /gstack-upgrade (not from a preamble):
>
> 1. Force a fresh update check (bypass cache):
>    ~/.claude/skills/gstack/bin/gstack-update-check --force
>
> 2. If UPGRADE_AVAILABLE: follow Steps 2-6.
>
> 3. If no output (already up to date): check for a stale local vendored copy.
> ```

**中文**：独立调用的完整决策树：

```
/gstack-upgrade 独立调用

    gstack-update-check --force
           │
    ┌──────┴──────┐
    │             │
UPGRADE         已是最新
AVAILABLE
    │             │
    ▼             ▼
执行 Steps 2-6  检测本地 vendored 副本
                    │
              ┌─────┴─────┐
              │           │
         LOCAL_GSTACK   无本地副本
           非空              │
              │             ▼
        ┌─────┴────┐   "You're already on
        │          │    the latest version"
   TEAM_MODE    非 team mode
     =true              │
        │         ┌─────┴────┐
        ▼         │          │
   删除 vendored  版本相同   版本不同
   副本           │          │
                  ▼          ▼
              "Both up    同步本地副本
               to date"   从主安装复制
```

**关键差异**：独立调用用 `--force` 绕过更新检查缓存；Preamble 触发时缓存未命中才检查。

---

## 六、gstack-update-check 工作机制

虽然源文件中只调用了二进制，但了解其工作原理有助于理解整个升级流程：

```
gstack-update-check 执行流程
──────────────────────────────────────────────
1. 检查缓存文件 ~/.gstack/last-update-check
   ├── 若存在且在缓存期内（通常 24h）→ 跳过（返回空）
   └── 若不存在或已过期 → 继续

2. 从 GitHub API 获取最新版本
   curl https://api.github.com/repos/garrytan/gstack/releases/latest

3. 读取本地版本
   cat $INSTALL_DIR/VERSION

4. 比较版本
   ├── 本地 == 远端 → 返回空（无需升级）
   ├── 本地 < 远端  → 输出 "UPGRADE_AVAILABLE <local> <remote>"
   └── 本地 > 远端  → 返回空（开发版本，不降级）

5. 更新缓存文件
   echo "$(date +%s)" > ~/.gstack/last-update-check

特殊情况：
   --force flag → 跳过步骤1，强制执行全流程
   升级完成后  → Step 5 删除缓存文件，下次必然重新检查
──────────────────────────────────────────────
```

---

## 七、配置系统与 gstack-config

`gstack-upgrade` 大量使用 `gstack-config` 读写配置，配置文件位于 `~/.gstack/config.yaml`。

升级相关的配置项：

| 配置键 | 类型 | 默认值 | 作用 |
|--------|------|--------|------|
| `auto_upgrade` | bool | `false` | 是否自动升级（跳过询问）|
| `update_check` | bool | `true` | 是否启用更新检查 |
| `team_mode` | bool | `false` | 是否使用团队模式（共享全局安装）|

**快速参考命令**：

```bash
# 开启自动升级
gstack-config set auto_upgrade true

# 关闭更新检查（永久不提醒）
gstack-config set update_check false

# 重新开启更新检查
gstack-config set update_check true

# 开启团队模式
gstack-config set team_mode true

# 通过环境变量临时开启自动升级（适合 CI/CD）
GSTACK_AUTO_UPGRADE=1 claude ...
```

---

## 八、与 Preamble 的集成关系

所有 gstack 技能的 Preamble（无论 tier 1/2/3/4）都包含以下片段：

> **原文（gstack 根 SKILL.md 第 22-23 行）**：
> ```bash
> _UPD=$(~/.claude/skills/gstack/bin/gstack-update-check 2>/dev/null || ...)
> [ -n "$_UPD" ] && echo "$_UPD" || true
> ```

> **原文（gstack 根 SKILL.md 第 106 行）**：
> "If output shows `UPGRADE_AVAILABLE <old> <new>`: read `~/.claude/skills/gstack/gstack-upgrade/SKILL.md`
> and follow the 'Inline upgrade flow'"

```
每次技能启动时的更新检测时序
─────────────────────────────────────────────────────────────────
用户调用 /qa（或任意技能）

    Preamble 执行（Bash 代码块）
         │
         ├── 1. gstack-update-check（缓存24h，快速）
         │       │
         │   输出 UPGRADE_AVAILABLE？
         │       ├── 是 → 读取 gstack-upgrade/SKILL.md
         │       │         执行 Inline 升级流程
         │       │         升级完成后继续...
         │       └── 否 → 继续
         │
         ├── 2. 读取 PROACTIVE、BRANCH、REPO_MODE 等配置
         ├── 3. 处理首次初始化（lake intro、telemetry、routing）
         └── 4. 技能主逻辑开始...
─────────────────────────────────────────────────────────────────
```

**设计亮点**：
- 更新检查有 24 小时缓存，不会每次都请求 GitHub API
- 对用户几乎无感——检查通常 < 100ms（命中缓存）
- 升级是**非阻断的**：用户选择 "Not now" 时技能正常继续

---

## 九、版本迁移脚本规范

从 CONTRIBUTING.md 提取的迁移脚本编写规范：

```bash
#!/bin/bash
# Migration: v1.2.0
# Purpose: Migrate config from old format to new format
# When: runs on upgrade from any version < 1.2.0
# Idempotent: yes (safe to run multiple times)

set -euo pipefail

OLD_CONFIG="$HOME/.gstack/config.json"
NEW_CONFIG="$HOME/.gstack/config.yaml"

# 幂等性检查：已迁移则跳过
if [ -f "$NEW_CONFIG" ] && ! [ -f "$OLD_CONFIG" ]; then
  echo "  Already migrated, skipping."
  exit 0
fi

# 执行迁移
if [ -f "$OLD_CONFIG" ]; then
  # 转换格式...
  mv "$OLD_CONFIG" "$OLD_CONFIG.bak"
fi

echo "  Migration v1.2.0 complete."
```

**命名规范**：`v{VERSION}.sh`，放在 `gstack-upgrade/migrations/` 目录下

**运行时机**：仅当从比该版本旧的版本升级时才运行（不会重复执行）

---

## 十、Team Mode（团队模式）

> **原文（Step 4.5 部分）**：
> "If `LOCAL_GSTACK` is non-empty AND `TEAM_MODE` is `true`: Remove the vendored copy.
> Team mode uses the global install as the single source of truth."

**中文**：Team Mode 的核心思想是"全局安装，集中管理"：

```
非团队模式（默认）                  团队模式
────────────────────              ────────────────────
每个开发者各自安装 gstack           一个人安装，其他人共享
版本可能不一致                     版本强制一致
本地 vendored 副本需要同步          删除本地副本，只用全局
```

**启用团队模式的步骤**（通常由团队负责人执行一次）：

```bash
# 1. 全局安装 gstack
cd ~/.claude/skills && git clone https://github.com/garrytan/gstack.git
cd gstack && ./setup

# 2. 运行团队初始化
~/.claude/skills/gstack/bin/gstack-team-init required  # 或 optional

# 3. 开启团队模式配置
gstack-config set team_mode true

# 4. 提交项目的 .claude/ 目录（包含 team mode 标记）
git add .claude/ && git commit -m "chore: enable gstack team mode"
```

---

## 十一、Vendoring 弃用说明

Preamble 中包含 Vendoring 检测，当检测到项目本地有 vendored 副本时会提醒迁移。

**为什么弃用 Vendoring？**

| 问题 | 说明 |
|------|------|
| 版本滞后 | vendored 副本不会自动更新，项目会逐渐落后 |
| 存储浪费 | 每个项目各存一份完整的 gstack（几 MB+）|
| 难以同步 | 升级时需要手动同步各项目的 vendored 副本 |
| PR 噪音 | 每次 gstack 升级都会产生大量文件变更的 PR |

**推荐迁移方案**（Team Mode 或 Global Git）：

```bash
# 迁移步骤（项目内执行）
git rm -r .claude/skills/gstack/
echo '.claude/skills/gstack/' >> .gitignore
~/.claude/skills/gstack/bin/gstack-team-init required
git add .claude/ .gitignore && git commit -m "chore: migrate gstack from vendored to team mode"
```

---

## 十二、JUST_UPGRADED 信号

Step 5 写入 `~/.gstack/just-upgraded-from` 后，下次 Preamble 运行时：

```bash
# gstack-update-check 会检测这个文件
# 若存在则输出 JUST_UPGRADED <from> <to>
```

当 Preamble 检测到 `JUST_UPGRADED <from> <to>` 时：

> **原文（gstack 根 SKILL.md 第 106 行结尾）**：
> "If `JUST_UPGRADED <from> <to>`: tell user 'Running gstack v{to} (just updated!)' and continue."

这让用户在升级后的**第一次技能调用**时看到确认消息，而不是静默升级。

---

## 十三、关键设计决策总结

| 决策 | 原因 |
|------|------|
| Inline 流程 vs 独立技能 | DRY 原则——升级逻辑只写一次，所有 Preamble 复用 |
| 4 选项（Yes/Always/Not now/Never）| 满足不同用户偏好：急用者、懒人、谨慎者、厌烦者 |
| Snooze 递增退避 | 避免永久骚扰（最长 1 周），也避免过于宽松（最短 24h）|
| `git reset --hard` 而非 `git pull` | 处理远端 force push/rebase 场景，保证干净状态 |
| 迁移脚本幂等性 | 网络失败重试时不产生副作用 |
| 升级后清除缓存 | 升级完立即生效，不等 24h 缓存过期 |
| `--force` flag（独立调用时）| 用户主动检查时，绕过缓存确保实时结果 |
| Team Mode | 团队协作场景下统一版本，减少"在我机器上能用"问题 |

---

## 十四、完整升级流程时序图

```
用户选择升级（或 auto_upgrade=true）

    ┌─────────────────────────────────────────────────────┐
    │                  升级流程全局视图                     │
    ├─────────────────────────────────────────────────────┤
    │                                                     │
    │  [Step 1] 询问用户 / 检查 auto_upgrade              │
    │      └── 用户选 "Not now" → 写 snooze → 结束         │
    │      └── 用户选 "Never" → 关闭 update_check → 结束   │
    │      └── 用户选 "Always" → 写 auto_upgrade=true      │
    │      └── 继续 Step 2                                │
    │                                                     │
    │  [Step 2] 检测 INSTALL_TYPE + INSTALL_DIR           │
    │                                                     │
    │  [Step 3] 记录 OLD_VERSION                          │
    │                                                     │
    │  [Step 4] 执行升级                                  │
    │      git stash → fetch → reset --hard → ./setup    │
    │      （或 clone + 覆盖，for vendored）               │
    │                                                     │
    │  [Step 4.5] 处理本地 vendored 副本（如有）           │
    │      team_mode=true → 删除                         │
    │      team_mode=false → 同步                        │
    │                                                     │
    │  [Step 4.75] 运行版本迁移脚本                       │
    │      仅运行 OLD_VERSION < m_ver 的脚本              │
    │                                                     │
    │  [Step 5] 写完成标记 + 清缓存                       │
    │      just-upgraded-from, last-update-check         │
    │                                                     │
    │  [Step 6] 展示 What's New                          │
    │      读 CHANGELOG.md，5-7 条，"Happy shipping!"    │
    │                                                     │
    │  [Step 7] 继续原始技能任务                          │
    │                                                     │
    └─────────────────────────────────────────────────────┘
```
