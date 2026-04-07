# `/guard` 技能逐段中英对照注解

> 对应源文件：[`guard/SKILL.md`](https://github.com/garrytan/gstack/blob/main/guard/SKILL.md)（82 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。
> 全安全模式——`/careful`（破坏性命令警告）与 `/freeze`（编辑目录锁定）的组合，适合生产环境操作。

---

## 这个技能是什么？

`/guard` 同时激活两层防护机制：

1. **破坏性命令警告**（来自 `/careful`）：`rm -rf`、`DROP TABLE`、`git push --force` 等 Bash 命令执行前弹出警告，用户可选择继续或取消
2. **编辑边界锁定**（来自 `/freeze`）：只允许编辑指定目录内的文件，边界外的 Edit/Write 被直接拒绝

**Guard = Careful + Freeze 的组合**，但不是简单拼接——guard 通过**引用**两个兄弟技能的脚本来实现，不重复任何逻辑。

**适用场景**：
- 生产环境排查 Bug（两层保护防止误操作）
- 在关键系统上进行维护操作
- 接触共享服务器上的敏感数据
- 任何"出了事情无法快速恢复"的高风险操作

**与单独使用 careful/freeze 的区别**：

```
/careful → 保护 Bash 命令层（只警告）
/freeze  → 保护文件修改层（强制边界）
/guard   → 同时保护两层（最高安全模式）
```

---

## Frontmatter（元数据区）解读

```yaml
---
name: guard
version: 0.1.0
description: |
  Full safety mode: destructive command warnings + directory-scoped edits.
  Combines /careful (warns before rm -rf, DROP TABLE, force-push, etc.) with
  /freeze (blocks edits outside a specified directory). Use for maximum safety
  when touching prod or debugging live systems. Use when asked to "guard mode",
  "full safety", "lock it down", or "maximum safety". (gstack)
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/../careful/bin/check-careful.sh"
          statusMessage: "Checking for destructive commands..."
    - matcher: "Edit"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/../freeze/bin/check-freeze.sh"
          statusMessage: "Checking freeze boundary..."
    - matcher: "Write"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/../freeze/bin/check-freeze.sh"
          statusMessage: "Checking freeze boundary..."
---
```

**逐字段解读**：

| 字段 | 值 | 含义 |
|------|----|------|
| `allowed-tools` | `Bash, Read, AskUserQuestion` | 与 `/freeze` 相同——需要询问用户锁定目录 |
| `hooks.PreToolUse[0]` | `matcher: "Bash"` | 拦截 Bash 工具（命令执行） |
| `hooks.PreToolUse[1]` | `matcher: "Edit"` | 拦截 Edit 工具（文件修改） |
| `hooks.PreToolUse[2]` | `matcher: "Write"` | 拦截 Write 工具（文件写入） |
| Bash hook command | `${CLAUDE_SKILL_DIR}/../careful/bin/check-careful.sh` | 引用 careful 的脚本（相对路径） |
| Edit/Write hook command | `${CLAUDE_SKILL_DIR}/../freeze/bin/check-freeze.sh` | 引用 freeze 的脚本（相对路径） |

**关键设计点**：

guard 的 hooks 一共注册了 **3 个 PreToolUse 拦截**：
- 1 个针对 Bash（careful 逻辑）
- 2 个针对 Edit/Write（freeze 逻辑）

而 guard 自己的 `bin/` 目录下**没有任何脚本**——全靠引用兄弟技能的脚本。

---

## Hook 脚本复用机制

> **原文**：
> ```
> **Dependency note:** This skill references hook scripts from the sibling /careful
> and /freeze skill directories. Both must be installed (they are installed together
> by the gstack setup script).
> ```

**中文解读**：guard 依赖 careful 和 freeze 的脚本，两者必须一起安装。gstack 的安装脚本保证了这一点。

### 路径解析

```
${CLAUDE_SKILL_DIR}/../careful/bin/check-careful.sh
```

拆解：
- `${CLAUDE_SKILL_DIR}` — guard 自己的技能目录，如 `~/.claude/skills/guard/`
- `/../` — 向上一级，到 `~/.claude/skills/`
- `careful/bin/check-careful.sh` — 进入 careful 的脚本目录

完整展开：
```
~/.claude/skills/careful/bin/check-careful.sh
~/.claude/skills/freeze/bin/check-freeze.sh
```

这要求所有 gstack 安全技能安装在同一个父目录下（`~/.claude/skills/`）。

### 为什么复用而不是复制？

```
方案 A：复制脚本到 guard/bin/
  guard/bin/check-careful.sh  ← careful 脚本的副本
  guard/bin/check-freeze.sh   ← freeze 脚本的副本

问题：
  - 双重维护负担：careful 更新了新模式，guard 也得手动更新
  - 容易出现版本漂移（careful 是最新的，guard 的副本是旧版）
  - 违反 DRY 原则

方案 B：引用兄弟技能脚本（实际方案）
  guard 不复制任何脚本，直接引用

优点：
  - careful 和 freeze 的任何更新自动被 guard 继承
  - 单一事实来源（Single Source of Truth）
  - guard 的代码量极小，逻辑完全委托给兄弟技能
```

### DRY 原则在技能设计中的体现

gstack 的三个安全技能形成了一个清晰的层次：

```
careful/
  └─ bin/check-careful.sh  ← Bash 命令检查逻辑的唯一实现

freeze/
  └─ bin/check-freeze.sh   ← 路径边界检查逻辑的唯一实现

guard/
  └─ （无脚本）             ← 零实现，完全委托
     SKILL.md 中引用：
       ../careful/bin/check-careful.sh
       ../freeze/bin/check-freeze.sh
```

这种设计让每个脚本的职责极其单一——`check-careful.sh` 只负责识别危险命令，`check-freeze.sh` 只负责检查路径边界。

---

## 激活时执行的分析脚本

> **原文**：
> ```bash
> mkdir -p ~/.gstack/analytics
> echo '{"skill":"guard","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","repo":"'...'"}' >> ~/.gstack/analytics/skill-usage.jsonl 2>/dev/null || true
> ```

记录使用日志，与所有 gstack 技能相同。写入 `~/.gstack/analytics/skill-usage.jsonl`，格式：

```json
{"skill": "guard", "ts": "2024-01-15T10:30:00Z", "repo": "my-project"}
```

---

## 启动流程（Setup）

> **原文**：
> ```
> ## Setup
>
> Ask the user which directory to restrict edits to. Use AskUserQuestion:
> - Question: "Guard mode: which directory should edits be restricted to?
>   Destructive command warnings are always on. Files outside the chosen path
>   will be blocked from editing."
> - Text input (not multiple choice) — the user types a path.
>
> Once the user provides a directory path:
> 1. Resolve it to an absolute path
> 2. Ensure trailing slash and save to the freeze state file
>
> Tell the user:
> - "Guard mode active. Two protections are now running:"
> - "1. Destructive command warnings — rm -rf, DROP TABLE, force-push, etc. will warn
>      before executing (you can override)"
> - "2. Edit boundary — file edits restricted to <path>/. Edits outside are blocked."
> - "To remove the edit boundary, run /unfreeze. To deactivate everything, end the session."
> ```

**中文完整启动流程**：

**Step 1：询问用户要锁定的目录**

```
Claude 弹出 AskUserQuestion：
"Guard mode: which directory should edits be restricted to?
Destructive command warnings are always on.
Files outside the chosen path will be blocked from editing."

（注意：问题里特别说明了 "Destructive command warnings are always on"——
 careful 部分不需要配置，会自动激活）

用户输入：./src/payment
```

**Step 2：解析为绝对路径**

```bash
FREEZE_DIR=$(cd "./src/payment" 2>/dev/null && pwd)
# 结果：/Users/me/project/src/payment
```

**Step 3：规范化并写入状态文件**

```bash
FREEZE_DIR="${FREEZE_DIR%/}/"
# /Users/me/project/src/payment → /Users/me/project/src/payment/

STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.gstack}"
mkdir -p "$STATE_DIR"
echo "/Users/me/project/src/payment/" > "$STATE_DIR/freeze-dir.txt"
```

注意：guard 只写入了 **freeze 的状态文件**（`freeze-dir.txt`）。careful 不需要状态文件——它的 hook 注册本身就是激活状态，无需额外配置。

**Step 4：告知用户两层防护已激活**

```
Guard mode active. Two protections are now running:

1. Destructive command warnings
   rm -rf, DROP TABLE, force-push, etc. will warn before executing (you can override)

2. Edit boundary
   File edits restricted to /Users/me/project/src/payment/
   Edits outside this directory are blocked.

To remove the edit boundary, run /unfreeze.
To deactivate everything, end the session.
```

### guard vs freeze 的 Setup 问题对比

| | `/freeze` | `/guard` |
|--|-----------|----------|
| 问题 | "Which directory should I restrict edits to?" | "Guard mode: which directory should edits be restricted to? Destructive command warnings are always on." |
| 差异 | 纯粹询问目录 | 同时告知 careful 已自动激活 |

guard 的问题措辞更完整，让用户在回答前就了解将要激活的两层防护。

---

## 三种安全级别对比

| 技能 | 触发词 | Bash 命令 | Edit 操作 | Write 操作 | 状态文件 | 关闭方式 |
|------|--------|-----------|-----------|------------|----------|----------|
| `/careful` | "be careful", "safety mode" | ⚠️ warn（可 override） | 无限制 | 无限制 | 无 | 结束对话 |
| `/freeze` | "freeze", "restrict edits" | 无限制 | 🚫 block（直接拒绝） | 🚫 block | `freeze-dir.txt` | `/unfreeze` 或结束对话 |
| `/guard` | "guard mode", "full safety" | ⚠️ warn | 🚫 block | 🚫 block | `freeze-dir.txt` | `/unfreeze`（partial）或结束对话 |

### 场景选择矩阵

```
问题：我需要哪种保护？

只担心自己执行危险命令（rm -rf 等）？
  → /careful

只担心 Claude 在调试时改了不相关的文件？
  → /freeze

生产环境，两个都担心？
  → /guard

调试结束，想解除目录限制但保留命令警告？
  → /unfreeze（在 guard 或 freeze 之后运行）
```

### 技能激活后的工具拦截矩阵

| 工具 | `/careful` 激活 | `/freeze` 激活 | `/guard` 激活 |
|------|----------------|----------------|---------------|
| Bash（安全命令） | ✅ 正常执行 | ✅ 正常执行 | ✅ 正常执行 |
| Bash（危险命令） | ⚠️ 警告确认 | ✅ 正常执行 | ⚠️ 警告确认 |
| Read | ✅ 正常执行 | ✅ 正常执行 | ✅ 正常执行 |
| Edit（边界内） | ✅ 正常执行 | ✅ 正常执行 | ✅ 正常执行 |
| Edit（边界外） | ✅ 正常执行 | 🚫 直接拒绝 | 🚫 直接拒绝 |
| Write（边界内） | ✅ 正常执行 | ✅ 正常执行 | ✅ 正常执行 |
| Write（边界外） | ✅ 正常执行 | 🚫 直接拒绝 | 🚫 直接拒绝 |
| Grep / Glob | ✅ 正常执行 | ✅ 正常执行 | ✅ 正常执行 |

---

## 工作原理：两个 Hook 并行运行

guard 激活后，每次工具调用的处理路径：

### Bash 工具路径（careful 部分）

```
用户说：执行 git push -f origin main
         │
         ▼
Claude 调用 Bash 工具
         │
         ▼
[PreToolUse hook 1 触发]
bash ${CLAUDE_SKILL_DIR}/../careful/bin/check-careful.sh
         │
    ┌────┴────┐
    │         │
    ▼         ▼
检测到        安全命令
"push -f"
    │         │
    ▼         ▼
返回         返回
"ask"        "allow"
    │
    ▼
弹出警告：
"检测到危险命令 git push --force，
历史重写操作可能影响其他协作者。
是否继续？"
```

### Edit/Write 工具路径（freeze 部分）

```
Claude 决定修改 /project/config/prod.yml
         │
         ▼
[PreToolUse hook 2 触发]（对于 Edit 工具）
bash ${CLAUDE_SKILL_DIR}/../freeze/bin/check-freeze.sh
         │
    ┌────┴────┐
    │         │
    ▼         ▼
/project/config/   /project/src/payment/
不在边界内         在边界内
    │               │
    ▼               ▼
返回 "deny"        返回 "allow"
    │
    ▼
操作被拒绝：
"File outside freeze boundary.
/project/config/prod.yml is outside
the allowed path /project/src/payment/"
```

### 两个 Hook 不会互相干扰

因为 careful hook 只对 Bash 工具触发，freeze hook 只对 Edit/Write 工具触发，两者覆盖不同的工具类型，没有重叠。

---

## 适合使用 guard 的典型场景

### 场景 1：生产数据库维护

```
背景：需要在生产数据库上修复一条错误数据

风险：
  - 误执行 DROP TABLE 或 TRUNCATE（数据灾难）
  - 顺手改了不相关的配置文件

解决方案：
  /guard → 锁定到 /app/db/migrations/

效果：
  - 任何 DROP/TRUNCATE 前都会警告（给一次后悔的机会）
  - 只能修改 migrations 目录里的文件（范围可控）
```

### 场景 2：线上服务排查

```
背景：某个微服务出现性能问题，需要在线调试

风险：
  - 误删日志文件（证据丢失）
  - 在调试 auth 服务时意外改了 billing 服务

解决方案：
  /guard → 锁定到 /services/auth/

效果：
  - rm -rf 操作前都有警告（不会误删日志）
  - billing、config 等其他目录的文件无法被修改
```

### 场景 3：共享开发服务器

```
背景：多人共用一台开发服务器，AI 在上面帮忙调试

风险：
  - AI 执行 rm -rf 误删共享资源
  - AI 改了其他同事正在开发的模块

解决方案：
  /guard → 锁定到当前用户的工作目录

效果：
  - 破坏性命令执行前必须确认
  - 只能改自己工作目录里的文件
```

### 场景 4：关键系统配置变更

```
背景：需要修改 Kubernetes 部署配置

风险：
  - kubectl delete 删掉错误的 pod/service
  - 修改了不相关的 K8s 资源

解决方案：
  /guard → 锁定到 /k8s/production/auth-service/

效果：
  - kubectl delete 前弹出警告
  - 只允许修改 auth-service 的 K8s 配置文件
```

---

## 退出 guard 模式的方式

guard 模式有两种退出途径，效果不同：

### 方式 1：`/unfreeze`（部分解除）

```bash
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.gstack}"
rm -f "$STATE_DIR/freeze-dir.txt"
```

效果：
- ✅ 编辑边界解除（Edit/Write 不再受限）
- ⚠️ 命令警告仍在（careful hook 仍然活跃）
- ✅ 可以再次运行 `/freeze` 设置新边界

适用场景：调试完指定模块，需要扩大编辑范围，但仍想保留命令安全提醒。

### 方式 2：结束对话（完全解除）

效果：
- ✅ 编辑边界解除
- ✅ 命令警告关闭
- 所有注册的 hooks 自动注销

适用场景：整个高风险操作已完成，不再需要任何安全保护。

```
guard 的安全层级示意：

[guard 模式]
  两层保护都激活
      │
      │ /unfreeze
      ▼
[partial guard 模式]
  只剩 careful 警告
      │
      │ 结束对话
      ▼
[完全关闭]
  所有保护都关闭
```

---

## 依赖安装说明

> **原文**：
> ```
> Dependency note: This skill references hook scripts from the sibling /careful
> and /freeze skill directories. Both must be installed (they are installed together
> by the gstack setup script).
> ```

**中文解读**：

guard 的 hook 引用了两个相对路径的脚本：
```
${CLAUDE_SKILL_DIR}/../careful/bin/check-careful.sh
${CLAUDE_SKILL_DIR}/../freeze/bin/check-freeze.sh
```

如果 careful 或 freeze 未安装，guard 的 hook 会报错（脚本文件不存在）。gstack 的安装脚本（setup script）总是同时安装整个技能包，所以正常安装的用户不会遇到这个问题。

**如果遇到 "脚本不存在" 错误**：
```bash
# 检查脚本是否存在
ls ~/.claude/skills/careful/bin/check-careful.sh
ls ~/.claude/skills/freeze/bin/check-freeze.sh
```

如果不存在，需要重新运行 gstack 安装脚本，或单独安装 careful 和 freeze 技能。

---

## guard 的受保护命令和例外（继承自 careful）

guard 对 Bash 命令的保护完全来自 `check-careful.sh`，规则与 `/careful` 完全一致：

**受保护命令**（执行前警告）：

| 模式 | 示例 | 风险 |
|------|------|------|
| `rm -rf` / `rm -r` | `rm -rf /var/data` | 递归删除 |
| `DROP TABLE` / `DROP DATABASE` | `DROP TABLE users;` | 数据丢失 |
| `TRUNCATE` | `TRUNCATE orders;` | 数据丢失 |
| `git push --force` / `-f` | `git push -f origin main` | 历史重写 |
| `git reset --hard` | `git reset --hard HEAD~3` | 未提交工作丢失 |
| `git checkout .` / `git restore .` | `git checkout .` | 工作区改动丢失 |
| `kubectl delete` | `kubectl delete pod` | 生产资源删除 |
| `docker rm -f` / `docker system prune` | `docker system prune -a` | 容器/镜像丢失 |

**安全例外**（不触发警告，直接放行）：
- `rm -rf node_modules` / `.next` / `dist` / `__pycache__` / `.cache` / `build` / `.turbo` / `coverage`

详细说明参见 [`careful.md`](./careful.md)。

---

## 核心设计思路

| 设计决策 | 原因 | 替代方案及其问题 |
|---------|------|-----------------|
| 复用 careful + freeze 的脚本（不复制） | DRY，careful/freeze 更新自动影响 guard | 复制后需要双重维护，容易版本漂移 |
| 通过相对路径引用兄弟技能 | 技能包整体移植时路径关系不变 | 硬编码绝对路径在不同用户主目录下会失效 |
| 两层防护叠加 | 生产场景需要最严格的保护 | 单层保护在高风险环境下不够 |
| /unfreeze 只解除 freeze 部分 | careful 和 freeze 是独立机制，应可独立控制 | 全部关闭意味着失去所有保护 |
| 状态文件路径与 /freeze 相同 | 一个状态文件，两个技能共用，避免混乱 | 分开的状态文件需要 unfreeze 知道"解的是哪个" |
| 依赖 gstack 安装脚本同时安装所有技能 | 避免用户手动管理技能依赖 | 用户可能只安装 guard 而没有 careful/freeze |

---

## 与整个安全体系的关系

```
gstack 安全技能族：

/careful ────────────────────→ Bash 命令保护
                                （warn-only，可 override）
                                        ↑
                                        │ 脚本复用
                                        │
/guard ──── check-careful.sh ──→ Bash 命令保护（同上）
     │
     └───── check-freeze.sh ──→ Edit/Write 文件保护
                                （deny，不可 override）
                                        ↑
                                        │ 脚本复用
                                        │
/freeze ─────────────────────→ Edit/Write 文件保护（同上）
                                写入 freeze-dir.txt
                                        ↑
                                        │ 删除文件
                                        │
/unfreeze ───────────────────→ 解除文件保护
                                （careful 不受影响）
```

四个技能形成一个完整的安全生态系统：
- careful 和 freeze 各自解决一个维度的问题
- guard 通过组合两者覆盖最高风险场景
- unfreeze 提供精细的部分解除能力

---

## 常见问题

**Q：`/guard` 和分别运行 `/careful` + `/freeze` 有什么不同？**
A：功能上完全相同——guard 就是一键激活两个的快捷方式。如果你已经在 careful 模式下，可以直接运行 `/guard` 来同时激活 freeze，不需要先关闭 careful。

**Q：`/guard` 激活后，`/careful` 的安全例外白名单还有效吗？**
A：有效。guard 引用的是 careful 的脚本，白名单逻辑完全相同。`rm -rf node_modules` 在 guard 模式下也不会触发警告。

**Q：我可以先激活 `/freeze`，再运行 `/guard` 吗？**
A：可以，但要注意：guard 会要求你重新输入目录，并覆盖 `freeze-dir.txt`。如果你想保留已有的 freeze 边界，不要运行 `/guard`——它的 Setup 步骤会重置边界。

**Q：`/guard` 模式下，Claude 能读取边界外的文件吗？**
A：可以。guard（和 freeze）只限制 Edit 和 Write 工具，不限制 Read、Glob、Grep——这些都是只读操作，不影响文件内容。

**Q：如果 careful 的脚本更新了（增加了新的危险模式），`/guard` 会自动获得更新吗？**
A：是的。因为 guard 引用的是 careful 的脚本文件路径，而不是脚本内容的副本。脚本文件更新后，下次 hook 触发时自动运行新版本。

**Q：能在 guard 模式下再次修改 freeze 边界吗（不结束对话）？**
A：可以。运行 `/unfreeze` 解除当前边界，然后运行 `/freeze` 设置新边界——或者直接运行 `/guard` 重新设置（会弹出询问新目录的问题）。careful 警告在整个过程中持续有效。
