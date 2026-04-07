# `/pair-agent` 技能逐段中英对照注解

> 对应源文件：[`pair-agent/SKILL.md`](https://github.com/garrytan/gstack/blob/main/pair-agent/SKILL.md)（826 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: pair-agent
version: 0.1.0
description: |
  Pair a remote AI agent with your browser. One command generates a setup key and
  prints instructions the other agent can follow to connect. Works with OpenClaw,
  Hermes, Codex, Cursor, or any agent that can make HTTP requests. The remote agent
  gets its own tab with scoped access (read+write by default, admin on request).
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---
```

**中文翻译**：

- **name**: `pair-agent`，"配对代理"——将另一个 AI 接入你的浏览器。
- **version: 0.1.0**: 早期版本标记（`0.x`），意味着 API 尚在演化。
- **description**: 把远程 AI 代理与你的浏览器配对。一条命令生成一个 setup key，打印出另一个代理可以跟随的连接指令。兼容 OpenClaw、Hermes、Codex、Cursor 或任何能发 HTTP 请求的代理。远程代理获得独立标签页，默认拥有 read+write 访问权（可请求 admin）。
- **allowed-tools**: 只有 `Bash`、`Read`、`AskUserQuestion` 三项。注意**没有 Write**——这个技能不改源码，只是配置代理连接。

> **设计原理：为什么只需要三个工具？**
> `pair-agent` 的核心工作是：检查 browse server 状态（Bash）、读取配置（Read）、询问用户（AskUserQuestion）。它不写文件、不改代码。职责极度单一。

---

## Preamble 展开区

`pair-agent` 使用标准 gstack Preamble（tier 默认）。Preamble 在运行时动态注入，包含：

1. **更新检查**：`gstack-update-check` 检测是否有新版本可升级
2. **会话追踪**：在 `~/.gstack/sessions/` 记录活跃 session，120 分钟过期清理
3. **环境变量读取**：`PROACTIVE`、`SKILL_PREFIX`、`REPO_MODE`、`BRANCH` 等
4. **Telemetry**：记录技能使用时间戳到 `~/.gstack/analytics/skill-usage.jsonl`
5. **SPAWNED_SESSION 检测**：若 `$OPENCLAW_SESSION` 存在，进入静默自动化模式（不弹 AskUserQuestion）

> **设计原理：SPAWNED_SESSION 模式**
> 这是 `/pair-agent` 最独特的地方——它本身就是为了让 AI 控制 AI 的浏览器而生的。如果运行它的上下文已经是另一个 AI orchestrator（如 OpenClaw）的子 session，就跳过所有交互提示，直接完成配对并报告结果。

---

## 原文：核心概念声明

> **原文**：
> ```
> # /pair-agent — Share Your Browser With Another AI Agent
>
> You're sitting in Claude Code with a browser running. You also have another AI agent
> open (OpenClaw, Hermes, Codex, Cursor, whatever). You want that other agent to be
> able to browse the web using YOUR browser. This skill makes that happen.
> ```

**中文**：你坐在 Claude Code 前，浏览器正在运行。你还开着另一个 AI 代理（OpenClaw、Hermes、Codex、Cursor，随便什么）。你想让那个代理能用**你的**浏览器浏览网页。这个技能让这件事成为可能。

> **设计原理：为什么要共享浏览器？**
> 不同 AI 代理各有所长——Claude 可能擅长代码，Codex 擅长补全，Hermes 擅长某类任务。让它们共享同一个已认证的浏览器 session，可以避免每个代理单独登录、单独维护 cookie 的麻烦。这是 AI 多代理协作的底层基础设施。

---

## 原文：工作原理

> **原文**：
> ```
> ## How it works
>
> Your gstack browser runs a local HTTP server. This skill creates a one-time setup key,
> prints a block of instructions, and you paste those instructions into the other agent.
> The other agent exchanges the key for a session token, creates its own tab, and starts
> browsing. Each agent gets its own tab. They can't mess with each other's tabs.
>
> The setup key expires in 5 minutes and can only be used once. If it leaks, it's dead
> before anyone can abuse it. The session token lasts 24 hours.
> ```

**中文**：你的 gstack 浏览器运行一个本地 HTTP 服务器。这个技能创建一个一次性 setup key，打印一块指令文本，然后你把这块文本粘贴到另一个代理里。那个代理用 key 换取 session token，创建自己的标签页，开始浏览。每个代理都有自己的标签页，它们无法干扰彼此的标签页。

> **安全设计**：
> - Setup key **5分钟过期**，**只能用一次** —— 即使泄露，攻击窗口极小
> - Session token **24小时有效** —— 足够一个工作日的协作
> - **Tab 隔离** —— 代理只能操作自己创建的 tab，无法读写其他代理或用户的 tab

安全模型概览：

```
用户（Claude Code）
    │
    ├─ 生成 setup key（一次性，5min过期）
    │       │
    │       └─> 粘贴给 远程代理
    │                   │
    │                   └─ 用 setup key 换取 session token
    │                               │
    │                   ┌───────────▼──────────────┐
    │                   │  gstack browse HTTP server│
    │                   │  localhost:PORT           │
    │                   │  ┌──────────────────────┐ │
    │                   │  │  Tab A（用户的）      │ │
    │                   │  │  Tab B（远程代理的）  │ │
    │                   │  └──────────────────────┘ │
    │                   └───────────────────────────┘
    │
    └─ 本地代理 / 远程代理（ngrok 隧道）
```

---

## 原文：本机 vs 远程

> **原文**：
> ```
> **Same machine:** If the other agent is on the same machine (like OpenClaw running
> locally), you can skip the copy-paste ceremony and write the credentials directly to
> the agent's config directory.
>
> **Remote:** If the other agent is on a different machine, you need an ngrok tunnel.
> The skill will tell you if one is needed and how to set it up.
> ```

**中文**：
- **同机器**：如果另一个代理在同一台机器上（比如本地运行的 OpenClaw），可以跳过复制粘贴仪式，直接把凭据写到代理的配置目录。
- **远程**：如果另一个代理在不同机器上，需要 ngrok 隧道。技能会告诉你是否需要，以及如何设置。

| 场景 | 凭据传递方式 | 是否需要 ngrok |
|------|------------|--------------|
| 同机 OpenClaw | 写入 `~/.openclaw/skills/gstack/browse-remote.json` | 否 |
| 同机 Codex | 写入 `~/.codex/skills/gstack/browse-remote.json` | 否 |
| 同机 Cursor | 写入 `~/.cursor/skills/gstack/browse-remote.json` | 否 |
| 跨机任意代理 | 用户复制指令块粘贴到另一代理 | 是 |

---

## 原文：Step 1-3 核心流程

> **原文（Step 1 检查 browse server）**：
> ```
> $B status 2>/dev/null
> If the browse server is not running, start it:
> $B goto about:blank
> ```

**中文**：检查 browse 守护进程是否在运行。若没有，用 `goto about:blank` 启动它（访问空白页即可激活服务器）。

> **原文（Step 2 询问目标代理）**：
> ```
> Which agent do you want to pair with your browser?
> A) OpenClaw (local or remote)
> B) Codex / OpenAI Agents (local)
> C) Cursor (local)
> D) Another Claude Code session (local or remote)
> E) Something else (generic HTTP instructions)
> ```

**中文**：询问要配对哪种代理，以便生成对应格式的指令块和写入对应的凭据目录。不同平台使用不同的命令格式（OpenClaw 用 `exec curl`，Cursor 用 terminal 命令）。

> **原文（Step 3 询问本机/远程）**：
> ```
> Same machine skips the copy-paste ceremony. Credentials are written directly to
> the agent's config directory. No tunnel needed.
> ```

**中文**：本机配对零摩擦，直接写文件；跨机需要生成指令块让用户手动粘贴。

---

## 原文：Step 4 执行配对

### 本机路径

> **原文**：
> ```
> $B pair-agent --local TARGET_HOST
> ```

**中文**：`--local` 标志让 browse CLI 直接把凭据写入目标代理的配置目录，无需任何手动操作。

### 远程路径

> **原文**：
> ```
> **CRITICAL: You MUST output the full instruction block to the user.** The command
> prints everything between ═══ lines. Copy the ENTIRE block verbatim into your
> response so the user can copy-paste it into their other agent.
> ```

**中文**：这是技能里少见的**全大写强制指令**。指令块包含认证信息，用户必须能看到完整内容才能粘贴到另一个代理里。AI 不能"概括"它——必须原文输出。

> **设计原理：为什么强制输出完整指令块？**
> LLM 有习惯性的"简化"倾向，会把长输出总结成"这是 ngrok URL 和 token"。但另一个代理需要的是精确的 curl 命令序列，任何改写都会破坏它。所以技能用 CRITICAL + 全大写来抵抗这种倾向。

---

## 原文：权限级别

> **原文**：
> ```
> With default (read+write) access:
> - Navigate to URLs, click elements, fill forms, take screenshots
> - Cannot execute arbitrary JavaScript, read cookies, or access storage
>
> With admin access (--admin flag):
> - Everything above, plus JS execution, cookie access, storage access
> - Use sparingly. Only for agents you fully trust.
> ```

**中文**：

| 权限级别 | 可以做 | 不能做 |
|---------|--------|--------|
| 默认（read+write）| 导航、点击、填表、截图 | JS 执行、读 cookie、访问 storage |
| admin（`--admin`）| 上述全部 + JS + cookie + storage | 其他代理的 tab |

> **设计原理：最小权限默认**
> 大多数 AI 协作任务只需要"看"和"点"，不需要 JS 执行权限。admin 模式等同于在浏览器里运行任意代码，危险性显著提升。默认关闭，显式 `--admin` 开启，符合最小权限原则。

---

## 原文：故障排除

> **原文**：
> ```
> "Tab not owned by your agent" — The remote agent tried to interact with a tab
> it didn't create. Tell it to run `newtab` first to get its own tab.
>
> "Token expired" — The 24-hour session expired. Run /pair-agent again.
> ```

**中文**：常见错误及处理：

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| Tab not owned by your agent | 代理尝试操作不属于自己的 tab | 让代理先运行 `newtab` |
| Domain not allowed | token 有域名限制 | 用更宽松的域名权限重新配对 |
| Rate limit exceeded | 每秒 >10 次请求 | 代理应等待 Retry-After 响应头 |
| Token expired | 24 小时 session 过期 | 重新运行 `/pair-agent` |
| Agent can't reach server | 远程情况下 ngrok 隧道未运行 | 检查 `$B status` |

---

## 原文：吊销访问

> **原文**：
> ```
> $B tunnel revoke AGENT_NAME  # 断开特定代理
> $B tunnel rotate             # 断开所有代理并轮转根 token
> ```

**中文**：`rotate` 会立即使**所有**已颁发的 scoped token 失效。紧急情况下的核武器。

---

## 完整流程总结图

```
用户输入 /pair-agent
        │
        ├─ Preamble（更新检查 / telemetry / session 追踪）
        │
        ├─ Step 1：检查 browse server 是否运行
        │           └─ 未运行 → $B goto about:blank 启动
        │
        ├─ Step 2：询问目标代理类型
        │           ├─ A) OpenClaw
        │           ├─ B) Codex
        │           ├─ C) Cursor
        │           ├─ D) Claude Code
        │           └─ E) 通用 HTTP
        │
        ├─ Step 3：询问本机 or 远程
        │           ├─ 本机 → Step 4a
        │           └─ 远程 → Step 4b
        │
        ├─ Step 4a（本机）：$B pair-agent --local TARGET_HOST
        │           └─ 凭据直接写入代理配置目录
        │
        ├─ Step 4b（远程）：
        │           ├─ 检测 ngrok（installed? authed?）
        │           │   ├─ 已安装已认证 → $B pair-agent --client TARGET_HOST
        │           │   ├─ 已安装未认证 → 引导用户获取 authtoken
        │           │   └─ 未安装 → 引导安装 ngrok → STOP
        │           └─ 输出完整指令块（CRITICAL：必须原文输出）
        │
        ├─ Step 5：验证连接（$B status 检查代理是否出现）
        │
        └─ 完成（代理获得独立 tab，可以开始浏览）

吊销：
  $B tunnel revoke AGENT_NAME  ← 断开特定代理
  $B tunnel rotate             ← 断开所有代理（核武器）
```

---

## 设计核心思路汇总表

| 设计决策 | 具体实现 | 背后原因 |
|---------|---------|---------|
| Setup key 一次性 + 5min 过期 | `pair-agent --client` 生成临时 key | 即使泄露也无法被滥用 |
| Tab 严格隔离 | 代理只能操作自己创建的 tab | 防止代理间相互干扰 |
| 最小权限默认 | read+write 默认，admin 显式开启 | 安全第一，按需升权 |
| 本机路径零摩擦 | `--local` 直接写配置文件 | 减少用户操作，降低出错率 |
| 强制输出完整指令块 | CRITICAL 全大写约束 | 防止 LLM 简化破坏指令完整性 |
| ngrok 自动检测 | `which ngrok + ngrok config check` | 自动判断是否需要隧道，减少用户决策负担 |
| SPAWNED_SESSION 静默模式 | 检测 `$OPENCLAW_SESSION` 环境变量 | 支持 AI orchestrator 自动化调用 |
| 允许工具只有 3 个 | Bash + Read + AskUserQuestion | 单一职责：只配对，不修改代码 |
