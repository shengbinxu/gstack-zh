# `/unfreeze` 技能逐段中英对照注解

> 对应源文件：[`unfreeze/SKILL.md`](https://github.com/garrytan/gstack/blob/main/unfreeze/SKILL.md)（40 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。
> 解除 `/freeze` 或 `/guard` 设置的编辑边界，恢复对所有目录的编辑权限。

---

## 这个技能是什么？

`/unfreeze` 通过**删除状态文件**（`~/.gstack/freeze-dir.txt`）来解除编辑边界。它是 `/freeze` 的反向操作。

**核心机制**：`check-freeze.sh` 脚本的工作原理是"有文件才限制，没文件就全放行"——所以删除文件等价于关闭限制，不需要修改任何 hook 注册。

**与直接结束对话的区别**：

| 关闭方式 | freeze 状态 | careful 状态 | 可重新激活？ |
|----------|------------|--------------|-------------|
| `/unfreeze` | 关闭（删除文件） | 保持活跃 | ✅ 可再次运行 `/freeze` |
| 结束对话 | 关闭（hook 注销） | 关闭（hook 注销） | 需要重新激活 |

适用场景：
- 调试特定模块完成后，需要扩大编辑范围，但不想结束当前对话
- 发现 freeze 锁定的目录不对，想换一个目录重新锁定
- `/guard` 模式下只想解除目录限制，保留 careful 的命令警告

---

## Frontmatter（元数据区）解读

```yaml
---
name: unfreeze
version: 0.1.0
description: |
  Clear the freeze boundary set by /freeze, allowing edits to all directories
  again. Use when you want to widen edit scope without ending the session.
  Use when asked to "unfreeze", "unlock edits", "remove freeze", or
  "allow all edits". (gstack)
allowed-tools:
  - Bash
  - Read
---
```

**逐字段解读**：

| 字段 | 值 | 含义 |
|------|----|------|
| `allowed-tools` | `Bash, Read` | 只需要执行 bash 命令（删除文件）和读取文件（确认状态） |
| hooks | 无 | unfreeze 本身不注册任何 hook——它是一次性操作，执行完即结束 |
| `AskUserQuestion` | 不在列表中 | 无需用户输入——直接删文件即可 |

**关键设计点**：

unfreeze 是 gstack 安全技能中最简单的一个——它不注册 hook，不需要配置，只做一件事：删除状态文件。

这里体现了一个重要的设计哲学：**操作的复杂性应与其职责匹配**。freeze 需要询问目录、规范化路径、写入文件；unfreeze 只需要删除文件。代码量差距反映了职责差距。

---

## 工作机制

> **原文**：
> ```bash
> STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.gstack}"
> if [ -f "$STATE_DIR/freeze-dir.txt" ]; then
>   PREV=$(cat "$STATE_DIR/freeze-dir.txt")
>   rm -f "$STATE_DIR/freeze-dir.txt"
>   echo "Freeze boundary cleared (was: $PREV). Edits are now allowed everywhere."
> else
>   echo "No freeze boundary was set."
> fi
> ```

**中文逐行解析**：

```bash
STATE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.gstack}"
# 与 /freeze 使用完全相同的路径逻辑
# 确保 unfreeze 和 freeze 操作同一个文件
```

```bash
if [ -f "$STATE_DIR/freeze-dir.txt" ]; then
# 先检查文件是否存在
# 原因：避免多余的报错，提供有意义的反馈
```

```bash
  PREV=$(cat "$STATE_DIR/freeze-dir.txt")
  # 在删除前读取内容，用于告知用户"之前锁定的是哪个目录"
  # 这是良好的 UX 设计：告诉用户"解除了什么"，不只是"解除了"
```

```bash
  rm -f "$STATE_DIR/freeze-dir.txt"
  # 核心操作：删除状态文件
  # -f 标志：即使文件不存在也不报错（防止竞态条件）
```

```bash
  echo "Freeze boundary cleared (was: $PREV). Edits are now allowed everywhere."
  # 输出包含了之前的边界路径，帮助用户确认解除的是预期的 freeze
```

```bash
else
  echo "No freeze boundary was set."
  # 幂等性保证：如果没有 freeze，unfreeze 也能安全运行，不会报错
fi
```

### 状态文件删除的机制原理

为什么**删除文件**而不是**写入"解冻"标记**？

```
方案 A：写入特殊标记
  freeze → echo "/path/to/dir/" > freeze-dir.txt
  unfreeze → echo "UNFROZEN" > freeze-dir.txt
  check-freeze.sh → 读取文件，检查是否为 "UNFROZEN"

问题：
  - check-freeze.sh 需要额外的逻辑处理 "UNFROZEN" 状态
  - 状态从"有文件"变成"文件内容的含义"，复杂度增加
  - 需要考虑文件格式、编码等问题

方案 B：删除文件（实际方案）
  freeze → echo "/path/to/dir/" > freeze-dir.txt
  unfreeze → rm -f freeze-dir.txt
  check-freeze.sh → 读取文件，文件不存在则 allow

优点：
  - check-freeze.sh 的逻辑极简："文件存在才检查，不存在直接放行"
  - 文件的存在/不存在本身就是状态，不需要解析内容
  - 天然支持"重新 freeze"：再次写入文件即可激活新边界
```

这是 Unix 哲学的体现：**用文件的存在性来表示布尔状态**，而不是文件内容。类似 nginx 的 `/var/run/nginx.pid`——文件存在表示进程运行，文件不存在表示进程停止。

---

## Hook 仍然活跃但无约束的设计

> **原文**：
> ```
> Note that /freeze hooks are still registered for the session — they will just
> allow everything since no state file exists. To re-freeze, run /freeze again.
> ```

**中文解读**：

执行 `/unfreeze` 后，`/freeze`（或 `/guard`）注册的 PreToolUse hook **仍然在运行**——只是因为 `freeze-dir.txt` 不存在，`check-freeze.sh` 读不到限制路径，所以对所有操作返回 allow。

```
/unfreeze 后的 Edit 操作流程：

Edit 工具调用
    │
    ▼
[PreToolUse hook 触发]
    │
    ▼
check-freeze.sh 运行
    │
    ▼
读取 freeze-dir.txt → 文件不存在
    │
    ▼
返回 permissionDecision: "allow"
    │
    ▼
Edit 正常执行
```

**为什么不注销 hook？**

这是一个刻意的架构决策：

1. **技术限制**：Claude Code 的会话级 hook 一旦注册，在当前会话内无法注销（hooks 是 session-scoped，没有提供动态注销 API）。

2. **设计简洁**：既然无法注销，就利用这个约束——让 hook 继续运行但通过状态文件控制行为。代码路径更简单，无需特殊处理"hook 已注销"的情况。

3. **重新激活零成本**：用户再次运行 `/freeze` 时，只需写入新的 `freeze-dir.txt`，下一次 Edit/Write 调用时 hook 就会读到新边界并开始执行限制。不需要重新注册 hook。

```
状态转换图：

[freeze 未激活]
      │
      │ /freeze 或 /guard
      ▼
[freeze 激活]  ←─────────────────────────────┐
      │                                       │
      │ /unfreeze                            │ /freeze（重新设置）
      ▼                                       │
[hook 运行中，但无约束]  ─────────────────────┘
      │
      │ 结束对话
      ▼
[hook 注销，彻底关闭]
```

---

## 与 /guard 的交互

`/guard` 在激活时注册了两类 hook：
1. **careful hook**（Bash 命令检查）
2. **freeze hook**（Edit/Write 路径检查）

`/unfreeze` 只删除 `freeze-dir.txt`，**只影响 freeze hook 的行为**，不影响 careful hook。

```
/guard 激活后运行 /unfreeze：

  Bash 命令  →  careful hook 仍然活跃（rm -rf 仍然警告）
  Edit/Write →  freeze hook 仍然运行，但因为没有 freeze-dir.txt
               → 全部返回 allow（目录限制已解除）
```

**实际使用场景**：

```
场景：生产环境排查，用了 /guard
  → 锁定到 /app/services/auth/
  → 调试完 auth 服务，发现需要修改配置文件（不在 auth/ 里）

用户: /unfreeze

效果：
  ✅ 可以编辑 /app/config/database.yml（目录限制解除）
  ✅ rm -rf 等命令仍然会警告（careful 仍然活跃）
  ✅ 生产安全保障得到部分保留
```

这是 unfreeze 最典型的使用场景——**部分解除**安全限制，而不是全部关闭。

---

## 重新冻结（Re-freeze）场景

unfreeze 之后可以立即再次运行 `/freeze` 设置新的边界：

```
场景：调试 auth 模块完成，接下来调试 payment 模块

用户: /unfreeze
→ 解除 /app/services/auth/ 的限制

用户: /freeze
Claude: "Which directory should I restrict edits to?"
用户: src/payment
→ 重新锁定到 /app/services/payment/
```

这个流程展示了 freeze/unfreeze 设计的灵活性：
- freeze 不是"一次性"的——可以在同一个会话内多次设置
- 每次 `/freeze` 都用新路径覆盖 `freeze-dir.txt`
- 历史边界自动被替换，不需要先 unfreeze

---

## 使用分析记录

> **原文**（技能主体）：
> ```bash
> mkdir -p ~/.gstack/analytics
> echo '{"skill":"unfreeze","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","repo":"'...'"}' >> ~/.gstack/analytics/skill-usage.jsonl 2>/dev/null || true
> ```

与所有 gstack 技能一样，激活时记录一条使用日志。这条日志在**解除边界之前**就执行，确保即使删除操作失败，使用记录也能保存。

---

## 与 /freeze 的对称性设计

| 维度 | `/freeze` | `/unfreeze` |
|------|-----------|-------------|
| 主要操作 | 写入状态文件 | 删除状态文件 |
| 配置输入 | 需要用户提供目录路径 | 无需输入 |
| Hook 注册 | 注册 Edit/Write hook | 不注册任何 hook |
| 执行后状态 | Edit/Write 受限 | Edit/Write 不受限 |
| 可重复运行 | 是（覆盖旧边界） | 是（幂等，无副作用） |
| 涉及工具 | Bash + Read + AskUserQuestion | Bash + Read |

**幂等性保证**：

```bash
# 连续运行 unfreeze 两次是安全的
/unfreeze → "Freeze boundary cleared (was: /path/). Edits allowed everywhere."
/unfreeze → "No freeze boundary was set."  ← 第二次不报错，正常返回
```

---

## 核心设计思路

| 设计决策 | 原因 |
|---------|------|
| 删除文件而非写标记 | check-freeze.sh 逻辑极简："文件存在才限制" |
| Hook 继续注册但无约束 | hooks 无法动态注销；通过状态文件控制行为 |
| 不影响 careful hook | careful 和 freeze 是独立机制，unfreeze 只管 freeze 部分 |
| 告知用户之前的边界路径 | 好的 UX：让用户确认解除的是预期的限制 |
| 幂等性 | 没有 freeze 时运行 unfreeze 不报错，安全可重复 |
| 无需用户输入 | 解除操作是无歧义的——不需要确认"解除哪个目录" |

---

## 常见问题

**Q：`/unfreeze` 会关闭 `/careful` 的警告吗？**
A：不会。unfreeze 只影响 freeze 的目录边界（通过删除 `freeze-dir.txt`）。careful 的 Bash 命令警告仍然活跃，需要结束对话才能关闭。

**Q：如果我没有运行过 `/freeze`，运行 `/unfreeze` 会怎样？**
A：安全运行，输出 `"No freeze boundary was set."`，不报错，无副作用。

**Q：`/unfreeze` 可以解除 `/guard` 设置的目录边界吗？**
A：可以。`/guard` 使用与 `/freeze` 完全相同的 `freeze-dir.txt` 文件，所以 unfreeze 对两者都有效。但注意：unfreeze 不会关闭 guard 的 careful 部分（命令警告仍在）。

**Q：如何完全关闭 `/guard` 模式（包括 careful 警告）？**
A：只能通过结束对话来完全关闭。unfreeze 只能部分解除（解除目录限制，保留命令警告）。

**Q：重新 `/freeze` 需要先 `/unfreeze` 吗？**
A：不需要。`/freeze` 直接覆盖 `freeze-dir.txt`，不管之前是否有边界。你可以直接运行 `/freeze` 设置新目录。
