# `/careful` 技能逐段中英对照注解

> 对应源文件：[`careful/SKILL.md`](https://github.com/garrytan/gstack/blob/main/careful/SKILL.md)（59 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。
> 破坏性命令守卫——在危险操作执行前弹出警告，用户可选择继续或取消。

---

## 这个技能是什么？

`/careful` 通过 Claude Code 的 **PreToolUse hook** 机制，在每次执行 Bash 命令前检查是否含有危险模式。发现危险命令时，返回 `permissionDecision: "ask"` 提示用户确认，用户可选择继续或取消。

**三个核心特征**：

1. **只警告，不阻止** — 与 `/freeze` 的硬拒绝不同，careful 是 soft gate，用户始终可以 override
2. **会话级别生效** — 激活后持续整个对话，结束对话即关闭，无需配置文件
3. **Hook 机制** — 零侵入实现，不修改任何代码，通过外置脚本完成检查

**适用场景一览**：
- 接触生产环境时（prod 数据库操作、线上服务器）
- 共享服务器上操作（误删一个文件可能影响多人）
- 不熟悉的代码库（不确定某个命令的副作用）
- 任何时候感觉"我得小心点"

**与相关技能的定位**：
```
/careful  ——→  Bash 命令软警告（warn-only，可 override）
/freeze   ——→  Edit/Write 硬阻止（block，不可 override）
/guard    ——→  careful + freeze 双重叠加（最高安全模式）
/unfreeze ——→  解除 freeze / guard 的目录边界
```

---

## Frontmatter（元数据区）解读

```yaml
---
name: careful
version: 0.1.0
description: |
  Safety guardrails for destructive commands. Warns before rm -rf, DROP TABLE,
  force-push, git reset --hard, kubectl delete, and similar destructive operations.
  User can override each warning. Use when touching prod, debugging live systems,
  or working in a shared environment. Use when asked to "be careful", "safety mode",
  "prod mode", or "careful mode". (gstack)
allowed-tools:
  - Bash
  - Read
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/bin/check-careful.sh"
          statusMessage: "Checking for destructive commands..."
---
```

**逐字段解读**：

| 字段 | 值 | 含义 |
|------|----|------|
| `name` | `careful` | 用户输入 `/careful` 触发 |
| `version` | `0.1.0` | 当前版本 |
| `allowed-tools` | `Bash, Read` | 只允许执行命令和读文件——careful 本身不需要写任何文件 |
| `hooks.PreToolUse` | `matcher: "Bash"` | 只拦截 Bash 工具，不影响 Edit/Write/Read/Grep |
| `command` | `check-careful.sh` | 实际检查逻辑在外部脚本中，而不是内联在 SKILL.md 里 |
| `statusMessage` | `"Checking for destructive commands..."` | Claude 界面上显示的状态提示 |

**关键设计点**：

1. **为什么 allowed-tools 没有 Edit/Write？**
   careful 的职责是"检查"而非"修改"。它不需要写任何文件——状态靠 hook 脚本读取命令内容来维持，不需要状态文件（这是它和 freeze 的重要区别）。

2. **为什么只拦截 Bash？**
   破坏性操作几乎都通过 Bash 执行（`rm`、`git`、`kubectl`、`docker` 等都是 shell 命令）。Edit/Write 是结构化的文件操作，由 `/freeze` 负责管理。两者分工明确。

3. **为什么检查逻辑放在 `check-careful.sh` 而不是内联？**
   外置脚本有三个好处：
   - 可以用完整的 bash 正则表达式，比 YAML 内联更灵活
   - 脚本可以独立更新，不影响 SKILL.md 结构
   - `/guard` 可以通过 `${CLAUDE_SKILL_DIR}/../careful/bin/check-careful.sh` 复用同一个脚本

> **设计原理：`CLAUDE_SKILL_DIR` 变量**
> 这是 gstack 框架注入的环境变量，指向当前技能的安装目录。例如 `~/.claude/skills/careful/`。
> 使用这个变量而不是硬编码路径，让技能可以安装在任意位置，保持可移植性。

---

## PreToolUse Hook 机制详解

PreToolUse hook 是 Claude Code 的底层拦截机制，理解它对于理解整个 gstack 安全体系至关重要。

### Hook 的触发时序

```
用户说 "执行 rm -rf /tmp/data"
         │
         ▼
Claude 决定调用 Bash 工具
         │
         ▼
[PreToolUse 阶段] — hook 在工具真正执行之前触发
         │
         ▼
bash ${CLAUDE_SKILL_DIR}/bin/check-careful.sh
         │
    ┌────┴────┐
    │         │
    ▼         ▼
检测到危险    安全命令
    │         │
    ▼         ▼
返回         返回
"ask"        "allow"
    │         │
    ▼         ▼
弹出警告    正常执行
用户确认
```

### Hook 的返回值语义

| 返回值 | 含义 | careful 的用法 |
|--------|------|----------------|
| `permissionDecision: "allow"` | 允许工具执行 | 命令安全，直接放行 |
| `permissionDecision: "ask"` | 暂停，询问用户 | 检测到危险模式，显示警告 |
| `permissionDecision: "deny"` | 直接拒绝 | careful 不用这个——那是 freeze 的风格 |

### Hook 的输入数据格式

`check-careful.sh` 脚本接收的是标准输入（stdin）的 JSON，格式如下：

```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf /var/data/logs"
  }
}
```

脚本从 `tool_input.command` 字段提取命令字符串，然后运行正则匹配。

### 会话级生命周期

```
开启 /careful
    │
    ▼
hooks 注册到当前会话
    │
    ├─── 每次 Bash 调用都触发 hook
    │
    ▼
结束对话 / 开始新对话
    │
    ▼
hooks 自动注销（无需手动清理）
```

这与 `/freeze` 不同——freeze 需要状态文件（持久化），而 careful 的"状态"就是 hook 是否注册，无需额外文件。

---

## 受保护的命令模式

> **原文**：
> ```
> ## What's protected
>
> | Pattern | Example | Risk |
> |---------|---------|------|
> | rm -rf / rm -r / rm --recursive | rm -rf /var/data | Recursive delete |
> | DROP TABLE / DROP DATABASE | DROP TABLE users; | Data loss |
> | TRUNCATE | TRUNCATE orders; | Data loss |
> | git push --force / -f | git push -f origin main | History rewrite |
> | git reset --hard | git reset --hard HEAD~3 | Uncommitted work loss |
> | git checkout . / git restore . | git checkout . | Uncommitted work loss |
> | kubectl delete | kubectl delete pod | Production impact |
> | docker rm -f / docker system prune | docker system prune -a | Container/image loss |
> ```

**中文完整对照**：

| 模式 | 示例命令 | 风险类型 | 严重程度 |
|------|----------|----------|----------|
| `rm -rf` / `rm -r` / `rm --recursive` | `rm -rf /var/data` | 递归删除，无法恢复 | ⚠️⚠️⚠️ |
| `DROP TABLE` / `DROP DATABASE` | `DROP TABLE users;` | 删除数据库表/库 | ⚠️⚠️⚠️ |
| `TRUNCATE` | `TRUNCATE orders;` | 清空表数据 | ⚠️⚠️⚠️ |
| `git push --force` / `-f` | `git push -f origin main` | 强制覆盖远端历史 | ⚠️⚠️⚠️ |
| `git reset --hard` | `git reset --hard HEAD~3` | 丢弃未提交工作 | ⚠️⚠️ |
| `git checkout .` / `git restore .` | `git checkout .` | 丢弃工作区改动 | ⚠️⚠️ |
| `kubectl delete` | `kubectl delete pod my-app` | 删除生产 K8s 资源 | ⚠️⚠️⚠️ |
| `docker rm -f` / `docker system prune` | `docker system prune -a` | 强制删除容器/镜像 | ⚠️⚠️ |

### 按风险类型分类

**数据丢失类**（最严重，通常不可逆）：
- `rm -rf`：文件系统层面的递归删除
- `DROP TABLE` / `DROP DATABASE`：SQL 层面的结构性删除
- `TRUNCATE`：SQL 层面的数据清空（保留表结构）

**代码历史篡改类**（影响团队协作）：
- `git push --force` / `-f`：强制覆盖远端，别人的提交可能丢失
- `git push --force-with-lease`：稍微安全一些，但 careful 仍然警告

**未保存工作丢失类**：
- `git reset --hard`：将工作区回滚到某个 commit，未 commit 的改动消失
- `git checkout .` / `git restore .`：丢弃工作区所有未暂存改动

**生产基础设施类**：
- `kubectl delete`：删除 Kubernetes 资源（Pod、Deployment、Service 等）
- `docker rm -f`：强制停止并删除容器
- `docker system prune`：清理所有未使用的 Docker 资源（可能包括镜像、卷）

### 为什么这些模式需要警告？

这些命令有一个共同特征：**执行后难以（或无法）恢复**。普通的 `rm file.txt` 错了可以从备份恢复，但 `rm -rf /prod/data` 可能意味着小时级别的数据恢复工作。AI 在帮助用户时，可能因为上下文理解偏差而执行了不该执行的破坏性命令——careful 就是在"AI 理解"和"真实执行"之间加一道确认。

---

## 安全例外白名单

> **原文**：
> ```
> ## Safe exceptions
>
> These patterns are allowed without warning:
> - rm -rf node_modules / .next / dist / __pycache__ / .cache / build / .turbo / coverage
> ```

**中文**：这些模式**不触发警告**，直接放行：

| 目录名 | 用途 | 为什么安全 |
|--------|------|------------|
| `node_modules` | Node.js 依赖 | 可通过 `npm install` 重新生成 |
| `.next` | Next.js 构建产物 | 可重新构建 |
| `dist` | 编译输出目录 | 可重新构建 |
| `__pycache__` | Python 字节码缓存 | Python 运行时自动重建 |
| `.cache` | 各类工具缓存 | 缓存，删了最多慢一次 |
| `build` | 构建目录 | 可重新构建 |
| `.turbo` | Turborepo 缓存 | 可重新构建 |
| `coverage` | 测试覆盖率报告 | 可重新生成 |

### 白名单的设计哲学：警告疲劳问题

如果 `rm -rf node_modules` 也触发警告，开发者会遇到什么？

```
用户: 帮我清理项目
Claude: 执行 rm -rf node_modules
[careful 警告]: "检测到危险命令 rm -rf，是否继续？"
用户: 继续
Claude: 执行 rm -rf .next
[careful 警告]: "检测到危险命令 rm -rf，是否继续？"
用户: 继续
...（重复 5 次）
用户: 好烦，关掉 careful
```

这就是"警告疲劳"（alert fatigue）——当警告太多、太频繁时，用户开始无脑点"继续"，安全机制失去意义。

正确的设计是：**只对真正有风险的操作警告**。删除构建产物是开发中的日常操作，不会造成不可恢复的损失。白名单就是在"安全性"和"可用性"之间取得平衡。

### 白名单的匹配方式

这些是**子字符串匹配**，不是精确匹配。即：
- `rm -rf ./frontend/node_modules` → 匹配 `node_modules` → **不触发警告**
- `rm -rf /src/dist/v2` → 匹配 `dist` → **不触发警告**
- `rm -rf /prod/data` → 无匹配 → **触发警告**

---

## 工作机制详解

> **原文**：
> ```
> ## How it works
>
> The hook reads the command from the tool input JSON, checks it against the
> patterns above, and returns permissionDecision: "ask" with a warning message
> if a match is found. You can always override the warning and proceed.
>
> To deactivate, end the conversation or start a new one. Hooks are session-scoped.
> ```

**中文逐句解析**：

**"The hook reads the command from the tool input JSON"**
- hook 脚本从标准输入接收 JSON，提取 `tool_input.command` 字段
- 这是 Claude Code 的标准 hook 数据格式

**"checks it against the patterns above"**
- 用 bash 正则（`grep -E` 或 `=~` 操作符）逐一匹配危险模式
- 先检查白名单，白名单命中则直接 allow，不继续检查危险模式

**"returns permissionDecision: 'ask' with a warning message"**
- 返回的 JSON 格式：`{"permissionDecision": "ask", "reason": "<警告信息>"}`
- `reason` 字段内容会显示在 Claude 界面上

**"You can always override the warning and proceed"**
- 这是 careful 的核心设计理念：**AI 建议，人类决定**
- 用户说"继续"或"是的执行"，Claude 就会执行
- careful 不阻止任何操作，只是让用户多一次确认的机会

**"Hooks are session-scoped"**
- hooks 的生命周期绑定到对话会话
- 不写入任何配置文件，不影响其他会话
- 关闭对话窗口 = 关闭 careful

### 警告信息的典型格式

当检测到危险命令时，用户看到的大致是：

```
⚠️ 检测到危险命令: rm -rf /var/data
风险：递归删除操作可能造成不可恢复的数据丢失。

是否继续执行？
[继续] [取消]
```

用户选择"继续"后，Claude 记录用户的覆盖决定，然后执行命令。

---

## Hook 脚本路径与安装结构

`check-careful.sh` 的完整路径是：

```
${CLAUDE_SKILL_DIR}/bin/check-careful.sh
```

展开后（典型安装）：

```
~/.claude/skills/careful/bin/check-careful.sh
```

安装目录结构：

```
~/.claude/skills/careful/
├── SKILL.md              ← 技能定义（本文档的源文件）
├── SKILL.md.tmpl         ← 模板源文件（用于生成 SKILL.md）
└── bin/
    └── check-careful.sh  ← 实际检查脚本
```

`/guard` 技能通过相对路径复用这个脚本：

```
${CLAUDE_SKILL_DIR}/../careful/bin/check-careful.sh
```

即从 guard 的技能目录向上一层，再进入 careful/bin/。这要求 careful 和 guard 安装在同一个父目录下——gstack 的安装脚本保证了这一点。

---

## 激活时执行的分析脚本

> **原文**（技能主体部分）：
> ```bash
> mkdir -p ~/.gstack/analytics
> echo '{"skill":"careful","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","repo":"'$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")'"}'  >> ~/.gstack/analytics/skill-usage.jsonl 2>/dev/null || true
> ```

**中文解读**：这段脚本在技能激活时立即执行（不是 hook，是技能主体代码），记录一条使用日志：

```json
{
  "skill": "careful",
  "ts": "2024-01-15T10:30:00Z",
  "repo": "my-project"
}
```

这是 gstack 的使用分析机制：
- 追加写入（`>>`），不覆盖历史
- 失败静默（`2>/dev/null || true`），不影响主流程
- 记录技能名、时间戳、所在仓库名

这些数据帮助 gstack 团队了解哪些技能被最常用，以便优先改进。

---

## 与其他安全技能的完整关系图

### 功能矩阵

| 技能 | 拦截目标 | 拦截强度 | 状态文件 | 可手动解除 |
|------|----------|----------|----------|------------|
| `/careful` | Bash 命令 | warn（可 override） | 无 | 无需（会话结束自动关） |
| `/freeze` | Edit/Write 操作 | block（不可 override） | `freeze-dir.txt` | `/unfreeze` |
| `/guard` | Bash + Edit/Write | warn + block | `freeze-dir.txt` | `/unfreeze`（partial） |

### 场景选择指南

```
接触生产数据库，只是要查询？
  → 不需要任何安全技能

接触生产数据库，可能要写入？
  → /careful（有危险命令时提醒）

在共享服务器调试特定服务？
  → /freeze（防止改到其他服务的文件）

在生产环境上排查关键 bug？
  → /guard（最严格，双重保护）
```

### guard = careful + freeze 的组合原理

```
/guard 激活时：
  ├─ hooks[Bash] → check-careful.sh  （复用 careful 脚本）
  └─ hooks[Edit/Write] → check-freeze.sh  （复用 freeze 脚本）

不是"继承"，是"引用"——guard 本身没有任何检查逻辑，
全靠两个兄弟技能的脚本。
```

这种设计的好处：
- careful 和 freeze 更新 → guard 自动获得更新
- 三个技能的检查逻辑始终一致
- 单一职责，每个脚本只做一件事

---

## 技能激活的完整流程

当用户输入 `/careful` 时，发生了什么：

```
1. Claude 读取 careful/SKILL.md
2. 执行主体代码（analytics 记录）
3. 注册 PreToolUse hook：
   - 每次 Bash 工具调用前，运行 check-careful.sh
4. 告知用户：安全模式已激活，以下命令会触发警告：...
5. 后续每次 Bash 调用：
   a. hook 触发，check-careful.sh 读取命令
   b. 检查白名单 → 命中则 allow
   c. 检查危险模式 → 命中则 ask（弹出警告）
   d. 无匹配则 allow
```

---

## 核心设计思路

| 设计决策 | 原因 | 替代方案及其问题 |
|---------|------|-----------------|
| 只警告不阻止 | 尊重用户判断，避免 AI 过度干预 | 硬阻止会让 AI 变得不可用（用户需要手动执行所有命令） |
| 白名单例外 | 减少警告疲劳，只对真正危险的操作提醒 | 无白名单会让 `rm -rf node_modules` 也警告，用户很快关掉 careful |
| 会话级别 | 按需激活，不污染全局配置 | 全局配置会影响所有项目，包括不需要保护的场景 |
| Hook 机制 | 零侵入——不需要修改任何代码 | 修改 claude.md 中的指令不够可靠，AI 可能忽略 |
| 外置检查脚本 | 逻辑可复用（guard 直接引用），独立可更新 | 内联逻辑无法被 guard 复用 |
| 分工明确（只管 Bash） | careful 专注命令层面，freeze 专注文件层面 | 让 careful 也管 Edit/Write 会与 freeze 重叠，逻辑混乱 |

---

## 常见问题

**Q：`sed -i 's/foo/bar/' /prod/config` 会触发警告吗？**
A：不会。careful 的模式表里没有 `sed -i`。这类"看起来安全但可能危险"的命令不在覆盖范围内。如果你担心意外编辑文件，配合 `/freeze` 锁定目录会更有效。

**Q：可以自定义危险模式列表吗？**
A：直接编辑 `~/.claude/skills/careful/bin/check-careful.sh` 即可。添加新的 `grep -E` 匹配规则或扩展白名单列表。

**Q：careful 对 `eval`、`curl | bash` 这类危险用法有保护吗？**
A：当前版本（0.1.0）不涵盖这些模式。careful 聚焦在最常见、最明确的破坏性操作，而不是试图穷举所有危险用法。

**Q：careful 会减慢 Claude 的响应速度吗？**
A：hook 脚本在本地执行，通常 <10ms。对用户感知来说完全无感。

**Q：我用 `/guard` 了，还需要单独激活 `/careful` 吗？**
A：不需要。`/guard` 已经包含了 careful 的所有功能（通过复用同一个检查脚本）。
