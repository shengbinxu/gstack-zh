# `/freeze` 技能逐段中英对照注解

> 对应源文件：[`freeze/SKILL.md`](https://github.com/garrytan/gstack/blob/main/freeze/SKILL.md)（82 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。
> 编辑范围锁定——阻止对指定目录外的文件进行 Edit 或 Write，防止调试时误改无关代码。

---

## 这个技能是什么？

`/freeze` 限制 Claude 只能编辑指定目录内的文件。任何针对边界外文件的 Edit 或 Write 操作都会被**直接阻止**（`permissionDecision: "deny"`，不弹确认框，直接拒绝）。

**与 `/careful` 的核心区别**：

| 维度 | `/careful` | `/freeze` |
|------|------------|-----------|
| 拦截目标 | Bash 命令 | Edit / Write 操作 |
| 拦截强度 | warn（用户可 override） | deny（硬拒绝） |
| 状态持久化 | 无（会话即关） | 有（`freeze-dir.txt` 文件） |
| 激活方式 | 直接激活，无需配置 | 需要询问用户目录 |
| 关闭方式 | 结束对话 | `/unfreeze` 或结束对话 |

**核心使用场景**：
- 调试特定模块时，防止 AI 随手改了其他不相关的文件
- 把变更范围锁定在一个服务目录内（如 `src/auth/`）
- 与 `/investigate` 配合使用（investigate 在锁定假设后自动调用 freeze 逻辑）
- 代码审查时，防止 Claude 在读取代码的过程中意外触发编辑

**一句话总结**：freeze 是"AI 只能在这个沙箱里写文件"——不是建议，是强制边界。

---

## Frontmatter（元数据区）解读

```yaml
---
name: freeze
version: 0.1.0
description: |
  Restrict file edits to a specific directory for the session. Blocks Edit and
  Write outside the allowed path. Use when debugging to prevent accidentally
  "fixing" unrelated code, or when you want to scope changes to one module.
  Use when asked to "freeze", "restrict edits", "only edit this folder",
  or "lock down edits". (gstack)
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
hooks:
  PreToolUse:
    - matcher: "Edit"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/bin/check-freeze.sh"
          statusMessage: "Checking freeze boundary..."
    - matcher: "Write"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/bin/check-freeze.sh"
          statusMessage: "Checking freeze boundary..."
---
```

**逐字段解读**：

| 字段 | 值 | 含义 |
|------|----|------|
| `allowed-tools` | `Bash, Read, AskUserQuestion` | 比 careful 多了 `AskUserQuestion`——需要询问用户目录 |
| `hooks.PreToolUse[0]` | `matcher: "Edit"` | 拦截 Edit 工具（修改现有文件） |
| `hooks.PreToolUse[1]` | `matcher: "Write"` | 拦截 Write 工具（创建新文件或覆盖写入） |
| `command` | 两个 matcher 使用**同一个脚本** | `check-freeze.sh` 统一处理两种工具 |
| `statusMessage` | `"Checking freeze boundary..."` | 两个 hook 显示相同的状态提示 |

**关键设计点**：

1. **为什么需要 AskUserQuestion？**
   freeze 需要知道"锁定到哪个目录"——这个信息必须从用户处获取。`/careful` 不需要任何配置就能激活，但 freeze 需要一个交互步骤。

2. **为什么同时拦截 Edit 和 Write？**
   Claude 对文件的修改操作有两种路径：
   - `Edit`：修改现有文件（最常用）
   - `Write`：创建新文件或全量覆盖写入（也是文件修改）
   两者都能改变文件系统状态，所以都需要拦截。

3. **为什么不拦截 Bash？**
   `sed -i`、`awk`、`echo > file` 这些 Bash 命令也能修改文件。freeze **不拦截**这些——这是刻意的设计（后面详述）。

4. **为什么两个 matcher 用同一个脚本？**
   `check-freeze.sh` 从 hook 输入 JSON 读取 `file_path` 字段，两种工具的 JSON 格式相同，同一个脚本可以处理。

> **与 careful 的互补性**：careful 管命令层（Bash），freeze 管文件层（Edit/Write）。两者分工明确，组合起来就是 `/guard`。

---

## PreToolUse Hook 拦截机制

### Edit 和 Write 的 Hook 输入格式

`check-freeze.sh` 接收的 JSON 格式：

**Edit 工具**：
```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/Users/me/project/src/old/legacy.ts",
    "old_string": "function foo() {",
    "new_string": "function bar() {"
  }
}
```

**Write 工具**：
```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/Users/me/project/src/new-file.ts",
    "contents": "export function ..."
  }
}
```

脚本提取 `tool_input.file_path`，与 `freeze-dir.txt` 中记录的目录路径比较。

### 路径比较逻辑

```bash
# check-freeze.sh 的核心逻辑（伪代码）
FREEZE_DIR=$(cat "$STATE_DIR/freeze-dir.txt" 2>/dev/null)

if [ -z "$FREEZE_DIR" ]; then
  # 没有状态文件 = 没有 freeze 约束，直接放行
  echo '{"permissionDecision": "allow"}'
  exit 0
fi

FILE_PATH=$(echo "$INPUT_JSON" | jq -r '.tool_input.file_path')

if [[ "$FILE_PATH" == "$FREEZE_DIR"* ]]; then
  # 文件路径以 freeze 目录开头，允许
  echo '{"permissionDecision": "allow"}'
else
  # 文件路径不在 freeze 目录内，拒绝
  echo '{"permissionDecision": "deny", "reason": "File outside freeze boundary: '$FREEZE_DIR'"}'
fi
```

### 为什么是 deny 而不是 ask？

```
careful → ask（提示用户确认，用户可以说"继续"）
freeze  → deny（直接拒绝，不给用户 override 的机会）
```

这个设计差异反映了两种不同的使用场景：

- **careful 场景**：用户临时需要执行一个"通常危险"的操作（如清理生产数据库的测试数据），这时需要一个确认机会而不是完全阻止。
- **freeze 场景**：用户明确告诉 Claude"只改这个目录"，如果 Claude 想改边界外的文件，那一定是搞错了——没有 override 的理由。

---

## 设置流程（Setup）完整示例

> **原文**：
> ```
> ## Setup
>
> Ask the user which directory to restrict edits to. Use AskUserQuestion:
> - Question: "Which directory should I restrict edits to? Files outside this path will be blocked from editing."
> - Text input (not multiple choice) — the user types a path.
>
> Once the user provides a directory path:
> 1. Resolve it to an absolute path:
>    FREEZE_DIR=$(cd "<user-provided-path>" 2>/dev/null && pwd)
>    echo "$FREEZE_DIR"
>
> 2. Ensure trailing slash and save to the freeze state file:
>    FREEZE_DIR="${FREEZE_DIR%/}/"
>    STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.gstack}"
>    mkdir -p "$STATE_DIR"
>    echo "$FREEZE_DIR" > "$STATE_DIR/freeze-dir.txt"
>    echo "Freeze boundary set: $FREEZE_DIR"
>
> Tell the user: "Edits are now restricted to <path>/. Any Edit or Write outside this directory will be blocked."
> ```

**中文完整流程**：

**Step 1：询问用户目录**
```
Claude 弹出 AskUserQuestion：
"Which directory should I restrict edits to?
Files outside this path will be blocked from editing."

用户输入（举例）：./src/auth
```

**Step 2：解析为绝对路径**
```bash
FREEZE_DIR=$(cd "./src/auth" 2>/dev/null && pwd)
# 结果：/Users/me/project/src/auth
```

为什么要用 `cd && pwd` 而不是直接用用户输入的路径？
- 用户可能输入相对路径（`./src/auth`、`../other-service`）
- 相对路径依赖当前工作目录，不稳定
- 绝对路径是确定性的，不会因为 `cd` 操作而失效

**Step 3：确保尾部斜杠**
```bash
FREEZE_DIR="${FREEZE_DIR%/}/"
# /Users/me/project/src/auth → /Users/me/project/src/auth/
```

这一步的重要性在下一节详述。

**Step 4：写入状态文件**
```bash
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.gstack}"
mkdir -p "$STATE_DIR"
echo "/Users/me/project/src/auth/" > "$STATE_DIR/freeze-dir.txt"
```

**Step 5：告知用户**
```
"Edits are now restricted to /Users/me/project/src/auth/.
Any Edit or Write outside this directory will be blocked.
To change the boundary, run /freeze again.
To remove it, run /unfreeze or end the session."
```

---

## 尾部斜杠（Trailing Slash）的重要性

> **原文**：
> ```
> Notes:
> - The trailing / on the freeze directory prevents /src from matching /src-old
> ```

**中文详解**：

假设 freeze 目录是 `/project/src`，没有尾部斜杠：

```
检查文件：/project/src-old/legacy.ts
路径前缀：/project/src
比较："/project/src-old/legacy.ts".startsWith("/project/src")
结果：true ← 错误！src-old 不应该被允许
```

加上尾部斜杠后：

```
检查文件：/project/src-old/legacy.ts
路径前缀：/project/src/
比较："/project/src-old/legacy.ts".startsWith("/project/src/")
结果：false ← 正确！src/ 不匹配 src-old/
```

```
检查文件：/project/src/auth/handler.ts
路径前缀：/project/src/
比较："/project/src/auth/handler.ts".startsWith("/project/src/")
结果：true ← 正确！子目录允许
```

### 路径前缀碰撞案例

在真实项目中，目录命名冲突比想象中更常见：

| freeze 目录 | 没有尾部斜杠时会误匹配 |
|-------------|----------------------|
| `/src` | `/src-old/`, `/src-backup/`, `/src2/` |
| `/api` | `/api-v2/`, `/api-gateway/` |
| `/service` | `/service-worker/`, `/services/` |
| `/app` | `/app-config/`, `/apple/` |

`${FREEZE_DIR%/}/` 这个 bash 参数展开的含义：
- `%/` — 从末尾删除一个斜杠（如果有的话）
- 再加 `/` — 追加一个斜杠

效果是：无论用户输入带不带斜杠，结果都是统一的带斜杠格式。

---

## 状态文件机制

> **原文**：
> ```
> ## How it works
>
> The hook reads file_path from the Edit/Write tool input JSON, then checks
> whether the path starts with the freeze directory. If not, it returns
> permissionDecision: "deny" to block the operation.
>
> The freeze boundary persists for the session via the state file. The hook
> script reads it on every Edit/Write invocation.
> ```

**状态文件的完整生命周期**：

```
/freeze 激活
    │
    ▼
写入 freeze-dir.txt
~/.gstack/freeze-dir.txt
（内容：/path/to/dir/）
    │
    ├─── Edit 调用 → check-freeze.sh 读取文件 → 判断是否允许
    ├─── Write 调用 → check-freeze.sh 读取文件 → 判断是否允许
    ├─── Edit 调用 → check-freeze.sh 读取文件 → 判断是否允许
    │    （每次调用都重新读文件）
    │
    ▼
/unfreeze 或结束会话
    │
    ▼
删除 freeze-dir.txt（或文件自然过期）
    │
    ▼
check-freeze.sh 找不到文件 → 全部 allow
```

### 为什么用文件而不是环境变量？

| 持久化方式 | 优点 | 缺点 |
|------------|------|------|
| 环境变量 | 读取快 | 无法跨子进程传递；Claude 上下文压缩后可能丢失 |
| 状态文件 | 跨进程、跨上下文压缩稳定 | 需要磁盘 I/O |

Claude Code 的上下文窗口有长度限制，触发 compaction 后，对话历史会被压缩。环境变量设置在 bash 子进程中，而 Claude 的主进程未必能访问到。**文件系统是最可靠的跨进程持久化机制**。

### 状态文件路径的优先级

```bash
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.gstack}"
```

- 首先检查 `$CLAUDE_PLUGIN_DATA` 环境变量（Claude Code 框架可能设置）
- 如果未设置，使用 `~/.gstack/` 作为默认目录

这让状态文件路径可配置，支持不同的安装环境（多用户系统、容器环境等）。

---

## 子目录处理

freeze 使用**前缀匹配**，不是精确匹配。这意味着：

```
freeze 目录：/project/src/auth/

允许的操作：
  ✅ Edit /project/src/auth/handler.ts
  ✅ Edit /project/src/auth/middleware/validate.ts
  ✅ Edit /project/src/auth/tests/handler.test.ts
  ✅ Write /project/src/auth/new-file.ts

拒绝的操作：
  ❌ Edit /project/src/api/routes.ts
  ❌ Edit /project/src/auth.ts    ← 注意：auth.ts 不在 auth/ 目录内
  ❌ Write /project/package.json
  ❌ Edit /project/src/components/Button.tsx
```

**深层子目录**也是允许的：

```
freeze 目录：/project/src/

允许：
  ✅ Edit /project/src/auth/handler.ts
  ✅ Edit /project/src/auth/middleware/jwt/verify.ts
  ✅ Edit /project/src/api/v2/routes/users.ts

拒绝：
  ❌ Edit /project/docs/README.md
  ❌ Edit /project/config/database.yml
```

---

## 不限制的操作

> **原文**：
> ```
> Notes:
> - Freeze applies to Edit and Write tools only — Read, Bash, Glob, Grep are unaffected
> - This prevents accidental edits, not a security boundary — Bash commands like
>   sed can still modify files outside the boundary
> ```

**不受 freeze 影响的工具**：

| 工具 | 操作类型 | 受 freeze 限制？ | 原因 |
|------|----------|-----------------|------|
| `Read` | 读取文件 | ❌ 否 | 只读，不改变文件 |
| `Bash` | 执行命令 | ❌ 否 | 太通用，过滤成本高 |
| `Glob` | 文件搜索 | ❌ 否 | 只读 |
| `Grep` | 内容搜索 | ❌ 否 | 只读 |
| `Edit` | 修改文件 | ✅ 是 | 直接修改文件内容 |
| `Write` | 写入文件 | ✅ 是 | 直接修改文件内容 |

**重要警告**：freeze 不是安全沙箱。

```bash
# 这些 Bash 命令仍然可以修改边界外的文件：
sed -i 's/foo/bar/' /project/config/database.yml  # 不受 freeze 限制！
echo "new content" > /project/README.md           # 不受 freeze 限制！
cp /project/src/auth/key.pem /project/backup/    # 不受 freeze 限制！
```

> **设计原理：为什么不拦截 Bash 中的文件修改操作？**
>
> 1. **技术复杂性**：要从任意 bash 命令中检测"这个命令会修改哪个文件"几乎不可能——命令可以通过变量、管道、子进程等方式间接修改文件。
>
> 2. **误判率高**：试图解析 bash 命令以提取文件路径，会有大量误报（把读取操作判断为写入）。
>
> 3. **定位不同**：freeze 的目标是防止 Claude 的**结构化文件操作**（Edit/Write）越界，不是防止所有可能的文件修改。
>
> 4. **配合 /careful 使用**：如果同时需要限制 Bash 命令，用 `/guard`——它同时激活 careful（管 Bash 层面）和 freeze（管 Edit/Write 层面）。

---

## 与 /investigate 的集成

`/investigate` 技能在定位到根因假设后，会**自动**调用 freeze 逻辑，将调试范围锁定在相关目录。这是技能间协作的一个典型例子：

```bash
# 来自 investigate/SKILL.md 的 Scope Lock 部分
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.gstack}"
mkdir -p "$STATE_DIR"
echo "<detected-directory>/" > "$STATE_DIR/freeze-dir.txt"
echo "Debug scope locked to: <detected-directory>/"
```

注意：这里直接写入 `freeze-dir.txt`，而不是调用 `/freeze` 技能——因为它不需要询问用户目录（investigate 已经分析出了相关目录）。这说明 freeze 的状态文件机制不仅仅是供 `/freeze` 技能写入的，任何技能都可以通过写入该文件来启用边界保护。

---

## 设置示例（完整对话演示）

```
用户: /freeze

Claude: Which directory should I restrict edits to?
        Files outside this path will be blocked from editing.
        (Please type a directory path)

用户: src/auth

Claude:
[执行]
$ FREEZE_DIR=$(cd "src/auth" 2>/dev/null && pwd)
$ FREEZE_DIR="${FREEZE_DIR%/}/"
$ echo "$FREEZE_DIR" > ~/.gstack/freeze-dir.txt
→ 输出: /Users/me/myproject/src/auth/

"Edits are now restricted to /Users/me/myproject/src/auth/.
Any Edit or Write outside this directory will be blocked.
To change the boundary, run /freeze again.
To remove it, run /unfreeze or end the session."

--- 之后的操作 ---

用户: 帮我修复 src/auth/handler.ts 里的 bug

Claude: [尝试 Edit /Users/me/myproject/src/auth/handler.ts]
→ hook 检查：路径以 /Users/me/myproject/src/auth/ 开头 → ✅ 允许
→ 成功编辑

用户: 顺手帮我更新一下 src/api/routes.ts

Claude: [尝试 Edit /Users/me/myproject/src/api/routes.ts]
→ hook 检查：路径不以 /Users/me/myproject/src/auth/ 开头 → ❌ 拒绝
→ 报告: "File edit blocked by freeze boundary.
          /Users/me/myproject/src/api/routes.ts is outside the allowed path
          /Users/me/myproject/src/auth/"
```

---

## 与 /unfreeze 和 /guard 的生命周期关系

```
时间轴：

t0: /freeze → 写入 freeze-dir.txt → Edit/Write 受限
  │
  ├─── t1: Edit src/auth/handler.ts → 允许（在边界内）
  ├─── t2: Edit src/api/routes.ts → 拒绝（在边界外）
  ├─── t3: 上下文压缩（Context Compaction）→ 状态文件仍在，保护不中断！
  ├─── t4: Edit src/auth/middleware.ts → 允许（仍在边界内）
  │
  ▼
t5: /unfreeze → 删除 freeze-dir.txt → Edit/Write 不再受限
（freeze 的 hook 仍然注册，但没有状态文件 = 全部允许）

或者：

t5: /freeze（再次运行） → 可以设置新的边界目录
```

**与 /guard 的共享状态**：

`/guard` 技能在激活时也写入同一个 `freeze-dir.txt` 文件。因此：
- `/unfreeze` 可以解除 `/guard` 设置的目录边界
- 但 `/unfreeze` 不会关闭 `/careful` 的命令警告（那个通过 hook 注销才能关）

---

## 核心设计思路

| 设计决策 | 原因 | 替代方案及其问题 |
|---------|------|-----------------|
| 阻止（deny）而非警告（ask） | 调试时需要强制边界——如果只是警告，AI 可能说"用户允许了"就越界 | ask 模式让边界形同虚设 |
| 文件持久化状态 | 上下文压缩后状态依然存在 | 内存变量/环境变量在上下文压缩后可能丢失 |
| 只限制 Edit/Write | 专注于可检测的结构化文件操作 | 拦截所有 Bash 会导致误判率极高 |
| 前缀匹配（不是精确匹配） | 允许子目录操作，符合"锁定到模块"的使用意图 | 精确匹配只能锁定单个目录，不允许子目录 |
| 尾部斜杠规范化 | 防止 `/src` 误匹配 `/src-old` | 无规范化会有前缀碰撞漏洞 |
| AskUserQuestion 交互 | 必须从用户获取目录——AI 无法猜测用户意图 | 默认锁定 cwd 会在错误目录上激活 |

---

## 常见问题

**Q：我能同时设置多个 freeze 目录吗？**
A：当前版本（0.1.0）不支持。`freeze-dir.txt` 只存储一个路径。如果需要锁定多个不相邻的目录，需要找一个包含它们的公共父目录（可能范围过宽）。

**Q：freeze 对绝对路径和相对路径都有效吗？**
A：freeze 目录存储的是**绝对路径**（在 Setup 阶段通过 `cd && pwd` 规范化）。Claude 的 Edit/Write 工具输入的 `file_path` 也是绝对路径。所以不存在相对路径的问题。

**Q：如果我在 freeze 激活期间运行 /investigate，会发生什么？**
A：investigate 会覆盖 `freeze-dir.txt`，将边界设置到它检测到的相关目录。这可能改变你之前设置的边界——如果这不是你想要的，在 investigate 完成后再运行 `/freeze` 重新设置。

**Q：freeze 会影响 Claude 用 Bash 命令读取文件吗（如 cat、head）？**
A：不会。freeze 只限制 Edit 和 Write 工具，Bash 工具不受限制——包括 `cat`、`head`、`tail` 等读取命令，也包括 `sed -i` 等写入命令。

**Q：freeze 的状态在多个 Claude 会话之间共享吗？**
A：理论上，`freeze-dir.txt` 文件是持久化的，如果另一个 Claude 会话也安装了 freeze hooks，它也会受到限制。但通常每个工作任务对应一个会话，这种跨会话情况不常见。
