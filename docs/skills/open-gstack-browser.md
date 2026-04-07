# `/open-gstack-browser` 技能逐段中英对照注解

> 对应源文件：[`open-gstack-browser/SKILL.md`](https://github.com/garrytan/gstack/blob/main/open-gstack-browser/SKILL.md)（770 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## 目录

1. [为什么需要可视浏览器？](#1-为什么需要可视浏览器)
2. [Frontmatter（元数据区）](#2-frontmatter元数据区)
3. [Preamble 与 Voice 设计](#3-preamble-与-voice-设计)
4. [Step 0：Pre-flight 清理](#4-step-0pre-flight-清理)
5. [Step 1：连接——`$B connect`](#5-step-1连接b-connect)
6. [Step 2：验证连接状态](#6-step-2验证连接状态)
7. [Step 3：引导用户找到 Side Panel](#7-step-3引导用户找到-side-panel)
8. [Step 4：Activity Feed 演示](#8-step-4activity-feed-演示)
9. [Step 5：Sidebar Chat 介绍](#9-step-5sidebar-chat-介绍)
10. [Step 6：后续操作指引](#10-step-6后续操作指引)
11. [Sidebar 扩展架构深度解析](#11-sidebar-扩展架构深度解析)
12. [Anti-bot 隐身补丁](#12-anti-bot-隐身补丁)
13. [Headed vs Headless 对比分析](#13-headed-vs-headless-对比分析)
14. [与 setup-browser-cookies 的关系](#14-与-setup-browser-cookies-的关系)
15. [核心设计决策汇总](#15-核心设计决策汇总)

---

## 1. 为什么需要可视浏览器？

### Headless 的局限性

gstack 的默认浏览器模式是 **headless**（无头）——Playwright 启动一个没有窗口的 Chromium 进程。这在大多数情况下够用，但有几类问题 headless 无法解决：

#### 问题 1：反爬虫和机器人检测

```
headless Chromium 访问某些网站时：

  网站检测到：
  ✗ navigator.webdriver = true     (Playwright 的标记)
  ✗ Chrome 没有扩展列表            (真实 Chrome 总有扩展)
  ✗ Canvas 指纹与真实 Chrome 不同   (渲染引擎微差异)
  ✗ 字体列表与真实系统不同

  结果：
  → Cloudflare 拦截
  → reCAPTCHA 验证
  → 页面跳转到 "访问被拒绝"
  → 测试结果完全不可靠
```

#### 问题 2：OAuth 和复杂身份验证

部分 OAuth 提供商（如 Google）专门检测 headless 浏览器并拒绝登录：

```
你想测试：/login with Google

headless 模式：
  $B goto https://accounts.google.com/oauth/...
  → 403 "This browser or app may not be secure"
  → 无法继续测试

headed 模式（真实可视 Chrome）：
  $B goto https://accounts.google.com/oauth/...
  → 正常显示登录页
  → 可以手动或通过 Cookie 完成验证
```

#### 问题 3：需要人眼确认的场景

有些情况，AI 的快照（snapshot）不够用——你需要亲眼看到页面：
- 动画效果是否流畅？
- 字体渲染是否正确？
- 响应式布局在 1440px 宽时是否对齐？
- 某个交互的时序感是否自然？

#### 问题 4：调试 AI 操作

当你想看到 AI 在"做什么"——每次 click、fill、goto 在真实浏览器里实时发生——headless 完全不可见。

### `/open-gstack-browser` 解决的核心问题

```
┌──────────────────────────────────────────────────────────────┐
│  /open-gstack-browser 启动后的状态                            │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  GStack Browser（重定品牌的 Chromium）                │    │
│  │  ┌────────────────────────────┐ ┌──────────────────┐ │    │
│  │  │  主页面区域                │ │  gstack Sidebar  │ │    │
│  │  │                            │ │  扩展（Side      │ │    │
│  │  │  你能看到 AI 的每一步操作   │ │  Panel）         │ │    │
│  │  │                            │ │                  │ │    │
│  │  │  → goto hacker news        │ │  Activity Feed:  │ │    │
│  │  │  → snapshot                │ │  ✓ goto          │ │    │
│  │  │  → click "Show HN"         │ │  ✓ snapshot      │ │    │
│  │  │                            │ │  ✓ click         │ │    │
│  │  └────────────────────────────┘ │                  │ │    │
│  │                                 │  Chat Tab:       │ │    │
│  │                                 │  "take snapshot  │ │    │
│  │                                 │   and describe"  │ │    │
│  │                                 └──────────────────┘ │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Frontmatter（元数据区）

> **原文**：
> ```yaml
> ---
> name: open-gstack-browser
> version: 0.2.0
> description: |
>   Launch GStack Browser — AI-controlled Chromium with the sidebar extension baked in.
>   Opens a visible browser window where you can watch every action in real time.
>   The sidebar shows a live activity feed and chat. Anti-bot stealth built in.
>   Use when asked to "open gstack browser", "launch browser", "connect chrome",
>   "open chrome", "real browser", "launch chrome", "side panel", or "control my browser".
>   Voice triggers (speech-to-text aliases): "show me the browser".
> allowed-tools:
>   - Bash
>   - Read
>   - AskUserQuestion
> ---
> ```

**中文翻译**：

- **name**: 技能名称。用户输入 `/open-gstack-browser` 触发。
- **version: 0.2.0**: 注意这个版本号比 `/setup-browser-cookies`（v1.0.0）**低**，说明这是一个相对较新的功能，仍处于快速迭代中。
- **description**: 启动 GStack Browser——带有内置侧边栏扩展的 AI 控制 Chromium。打开一个可见的浏览器窗口，你可以实时观看每一个操作。侧边栏显示实时活动流和聊天。内置反机器人隐身功能。
- **语音触发别名**: "show me the browser"、"open chrome"、"real browser"、"side panel"、"control my browser"
- **allowed-tools**: 只有 `Bash`、`Read`、`AskUserQuestion`

> **设计原理：version 0.2.0 意味着什么？**
>
> gstack 的版本语义：1.0+ 是稳定版本，0.x 是功能完整但 API 可能变化。这个技能的核心功能（启动 headed Chrome、Sidebar 扩展）已经可用，但 Sidebar 聊天（child AI agent）是相对新的特性，还在演进中。

> **设计原理：为什么没有 `preamble-tier` 字段？**
>
> 和 `/setup-browser-cookies` 相比，`/open-gstack-browser` 的 frontmatter 中**没有 `preamble-tier`**。这意味着它使用完整的 preamble（包括 Voice 定义、Context Recovery、AskUserQuestion 格式规范等），而不是轻量级 tier 1。
>
> 原因：这个技能有复杂的交互流程（多步 AskUserQuestion、引导用户操作），需要完整的 Voice 和格式规范。

---

## 3. Preamble 与 Voice 设计

`/open-gstack-browser` 使用**完整 preamble**，其中最重要的差异是 **Voice**（声音/语调）定义。

### 3.1 Voice 设计哲学

> **原文（节选）**：
> ```
> ## Voice
>
> You are GStack, an open source AI builder framework shaped by Garry Tan's product,
> startup, and engineering judgment. Encode how he thinks, not his biography.
>
> Lead with the point. Say what it does, why it matters, and what changes for the
> builder. Sound like someone who shipped code today and cares whether the thing
> actually works for users.
>
> **Core belief:** there is no one at the wheel. Much of the world is made up.
> That is not scary. That is the opportunity. Builders get to make new things real.
> ```

**中文**：你是 GStack，一个由 Garry Tan 的产品、创业和工程判断塑造的开源 AI 构建框架。编码他的思维方式，而不是他的履历。

直接说重点。说它做什么、为什么重要、对构建者有什么改变。听起来像一个今天刚发布了代码、真正关心产品对用户是否有效的人。

> **设计原理：为什么 Voice 写得这么详细？**
>
> `/open-gstack-browser` 是一个**高交互技能**——它有多个 AskUserQuestion 步骤，需要引导不熟悉 Chrome 扩展的用户找到 Side Panel。错误的语调会：
> - 太学术 → 用户看不懂
> - 太谨慎 → 让用户觉得技术很难
> - 太 PR → 失去信任
>
> "builder talking to a builder" 的语调让技术指导自然、直接、有力度。

### 3.2 具体语调规则对比

| 禁止 | 推荐 |
|------|------|
| "It is important to understand..." | "What's interesting here is..." |
| "Furthermore, additionally..." | 短句。有时候一句话。 |
| "Comprehensive, robust, nuanced" | 直接说功能、文件、命令 |
| "Here's the kicker..." | 干燥的幽默观察 |
| 结论放最后 | 结论放最前，细节在后 |

### 3.3 Context Recovery（上下文恢复）

> **原文**：
> ```bash
> eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
> _PROJ="${GSTACK_HOME:-$HOME/.gstack}/projects/${SLUG:-unknown}"
> if [ -d "$_PROJ" ]; then
>   echo "--- RECENT ARTIFACTS ---"
>   find "$_PROJ/ceo-plans" "$_PROJ/checkpoints" ...
>   [ -f "$_PROJ/timeline.jsonl" ] && tail -5 "$_PROJ/timeline.jsonl"
>   _LAST=$(grep "\"branch\":\"${_BRANCH}\"" ... | grep '"event":"completed"' | tail -1)
>   [ -n "$_LAST" ] && echo "LAST_SESSION: $_LAST"
> ```

**中文**：在上下文压缩（compaction）后或会话开始时检查最近的项目产物。

`/open-gstack-browser` 是完整 preamble，所以包含这个 Context Recovery 块。这意味着：

- 如果你上次在这个分支运行了 `/qa`，重新打开浏览器时 AI 会自动恢复上下文
- 如果有 checkpoint，会读取 checkpoint 了解工作进度
- "Welcome back" 消息会告诉你上次的状态

---

## 4. Step 0：Pre-flight 清理

> **原文**：
> ```
> ## Step 0: Pre-flight cleanup
>
> Before connecting, kill any stale browse servers and clean up lock files that
> may have persisted from a crash. This prevents "already connected" false
> positives and Chromium profile lock conflicts.
>
> ```bash
> # Kill any existing browse server
> if [ -f "$(git rev-parse --show-toplevel 2>/dev/null)/.gstack/browse.json" ]; then
>   _OLD_PID=$(cat ... | grep -o '"pid":[0-9]*' | grep -o '[0-9]*')
>   [ -n "$_OLD_PID" ] && kill "$_OLD_PID" 2>/dev/null || true
>   sleep 1
>   [ -n "$_OLD_PID" ] && kill -9 "$_OLD_PID" 2>/dev/null || true
>   rm -f ".gstack/browse.json"
> fi
> # Clean Chromium profile locks (can persist after crashes)
> _PROFILE_DIR="$HOME/.gstack/chromium-profile"
> for _LF in SingletonLock SingletonSocket SingletonCookie; do
>   rm -f "$_PROFILE_DIR/$_LF" 2>/dev/null || true
> done
> echo "Pre-flight cleanup done"
> ```
> ```

**中文**：在连接之前，杀掉所有过时的 browse 服务器，清理可能在崩溃后残留的锁文件。这防止了 "already connected" 假阳性和 Chromium profile 锁冲突。

### 为什么需要 Pre-flight 清理？

Chromium 在运行时会在 profile 目录创建三个锁文件：

```
~/.gstack/chromium-profile/
├── SingletonLock     → 表示 "有一个 Chrome 实例正在使用这个 profile"
├── SingletonSocket   → 实例间通信的 Unix socket
└── SingletonCookie   → Cookie 防重叠标记
```

**正常关闭时**：Chromium 自动删除这些文件。

**崩溃时**：文件残留。下次启动时，Chromium 看到 `SingletonLock` 就认为"已经有一个实例在运行"，拒绝启动，或启动成功但报错。

```
场景：上次 Claude 会话在浏览器打开的情况下被强制关闭

残留状态：
  .gstack/browse.json        (PID: 12345，但进程已经不存在)
  ~/.gstack/chromium-profile/SingletonLock  (Chromium 的锁文件)

不做清理直接连接：
  $B connect
  ERROR: "Address already in use" 或
  ERROR: "Chromium failed to start: another instance is running"

做了清理再连接：
  Pre-flight cleanup done
  $B connect
  Mode: headed ✓
```

### 清理的两步操作

**Step A：终止旧的 browse 服务进程**

```bash
_OLD_PID=$(cat ".gstack/browse.json" | grep -o '"pid":[0-9]*' | grep -o '[0-9]*')
kill "$_OLD_PID" 2>/dev/null || true   # 发送 SIGTERM（优雅关闭）
sleep 1                                  # 给进程 1 秒时间响应
kill -9 "$_OLD_PID" 2>/dev/null || true  # 如果没响应，强制杀死
rm -f ".gstack/browse.json"             # 清理状态文件
```

为什么先 `kill` 再 `kill -9`？
- SIGTERM 让进程有机会做清理（关闭连接、保存状态）
- 如果 1 秒内没响应，再用 SIGKILL 强制终止
- `2>/dev/null || true` 确保即使进程已经不存在，命令也不会报错

**Step B：删除 Chromium 锁文件**

```bash
for _LF in SingletonLock SingletonSocket SingletonCookie; do
  rm -f "$_PROFILE_DIR/$_LF" 2>/dev/null || true
done
```

这三个文件是 Chromium 的"进程独占"机制的实现。删除它们不会损坏 profile 数据（Cookie、历史记录等），只是告诉下一个 Chromium 实例"可以使用这个 profile"。

---

## 5. Step 1：连接——`$B connect`

> **原文**：
> ```
> ## Step 1: Connect
>
> $B connect
>
> This launches GStack Browser (rebranded Chromium) in headed mode with:
> - A visible window you can watch (not your regular Chrome — it stays untouched)
> - The gstack sidebar extension auto-loaded via `launchPersistentContext`
> - Anti-bot stealth patches (sites like Google and NYTimes work without captchas)
> - Custom user agent and GStack Browser branding in Dock/menu bar
> - A sidebar agent process for chat commands
>
> The `connect` command auto-discovers the extension from the gstack install
> directory. It always uses port 34567 so the extension can auto-connect.
>
> After connecting, print the full output to the user. Confirm you see
> `Mode: headed` in the output.
> ```

**中文**：这会以 headed 模式启动 GStack Browser（重新定品牌的 Chromium），包含：
- 一个你可以观看的可见窗口（不是你的常规 Chrome——它保持不变）
- 通过 `launchPersistentContext` 自动加载的 gstack 侧边栏扩展
- 反机器人隐身补丁（Google、NYTimes 等网站无需验证码即可访问）
- 自定义 User Agent 和 Dock/菜单栏的 GStack Browser 品牌标识
- 用于聊天命令的侧边栏 agent 进程

### `$B connect` 的底层实现

```
$B connect 执行时：

1. Playwright launchPersistentContext()
   ├── headless: false              (可见窗口)
   ├── channel: "chromium"          (使用 gstack 安装的 Chromium)
   ├── userDataDir: ~/.gstack/      (持久化 profile)
   │   chromium-profile/
   ├── args: [                      (反机器人参数)
   │   "--disable-blink-features=AutomationControlled",
   │   "--no-first-run",
   │   ...
   │   ]
   └── extensions: [                (自动加载扩展)
       "/path/to/gstack/extension"
       ]

2. 注入 stealth 脚本
   ├── 删除 navigator.webdriver
   ├── 修改 navigator.plugins
   └── 修改 chrome.runtime API

3. 启动 sidebar agent 子进程
   └── 独立的 Claude 实例，监听 localhost:34567/sidebar

4. 写入状态文件
   └── .gstack/browse.json: { "pid": ..., "port": 34567, "mode": "headed" }
```

### 为什么使用 `launchPersistentContext` 而不是普通的 `launch`？

| 方法 | 特点 | 扩展支持 |
|------|------|---------|
| `browser.launch()` | 每次全新会话 | ❌ 不支持扩展 |
| `browser.launchPersistentContext()` | 持久化 profile | ✅ 支持扩展 |

Chrome 扩展需要持久化的 profile 目录才能安装。`launchPersistentContext` 提供了这个目录，所以 gstack Sidebar 扩展可以在每次启动时自动加载。

### "不是你的常规 Chrome" 的意义

```
用户的常规 Chrome                    GStack Browser（Playwright 控制的 Chromium）
~/Library/Application Support/       ~/.gstack/chromium-profile/
Google/Chrome/                        │
├── Default/                          ├── Cookies（独立，不与常规 Chrome 共享）
│   ├── Cookies                       ├── Extensions/（只有 gstack 扩展）
│   ├── History                       └── SingletonLock（运行时）
│   └── ...（你的个人数据）

完全隔离！AI 操作不会影响你的个人浏览记录、书签、密码
```

这个隔离设计非常重要：你可以放心让 AI 控制这个浏览器，不用担心它会改动你的个人 Chrome 数据。

### 端口 34567 的意义

`connect` 命令**总是**使用端口 34567。这不是随机选择——Sidebar 扩展的代码里硬编码了这个端口，所以：

1. 扩展启动时自动连接 `localhost:34567`，无需用户配置
2. AI 通过 `$B` 命令与 browse 服务通信，也是 34567
3. `/setup-browser-cookies` 的 Cookie 选择器也是 34567

单一端口 = 零配置连接。

---

## 6. Step 2：验证连接状态

> **原文**：
> ```
> ## Step 2: Verify
>
> $B status
>
> Confirm the output shows `Mode: headed`. Read the port from the state file:
>
> cat "$(git rev-parse --show-toplevel 2>/dev/null)/.gstack/browse.json" 2>/dev/null
>   | grep -o '"port":[0-9]*' | grep -o '[0-9]*'
>
> The port should be 34567.
>
> Also find the extension path so you can help the user if they need to load it manually:
> _EXT_PATH=""
> _ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
> [ -n "$_ROOT" ] && [ -f "$_ROOT/.claude/skills/gstack/extension/manifest.json" ]
>   && _EXT_PATH="$_ROOT/.claude/skills/gstack/extension"
> [ -z "$_EXT_PATH" ] && [ -f "$HOME/.claude/skills/gstack/extension/manifest.json" ]
>   && _EXT_PATH="$HOME/.claude/skills/gstack/extension"
> echo "EXTENSION_PATH: ${_EXT_PATH:-NOT FOUND}"
> ```

**中文**：确认输出显示 `Mode: headed`。读取状态文件中的端口（应为 34567）。找到扩展路径，以便在用户需要手动加载时提供帮助。

### `$B status` 的典型输出

```
$ $B status

GStack Browse Server
  Mode: headed          ← 关键：确认是可视模式
  Port: 34567
  PID: 45123
  Profile: ~/.gstack/chromium-profile
  Connected: true
  Pages: 1 open
  Extension: loaded
```

如果 `Mode: headless`，说明 `$B connect` 没有正确启动 headed 模式。如果 `Extension: not loaded`，需要手动加载扩展。

### 扩展路径搜索逻辑

```
搜索优先级：
  1. <git-root>/.claude/skills/gstack/extension/manifest.json
     （项目级 / 团队模式安装）
          ↓ 如果不存在
  2. ~/.claude/skills/gstack/extension/manifest.json
     （用户级全局安装）
          ↓ 如果都不存在
  输出 EXTENSION_PATH: NOT FOUND
  → 用户需要重新安装 gstack
```

---

## 7. Step 3：引导用户找到 Side Panel

> **原文**：
> ```
> ## Step 3: Guide the user to the Side Panel
>
> Use AskUserQuestion:
>
> > Chrome is launched with gstack control. You should see Playwright's Chromium
> > (not your regular Chrome) with a golden shimmer line at the top of the page.
> >
> > The Side Panel extension should be auto-loaded. To open it:
> > 1. Look for the puzzle piece icon (Extensions) in the toolbar
> > 2. Click the puzzle piece → find gstack browse → click the pin icon
> > 3. Click the pinned gstack icon in the toolbar
> > 4. The Side Panel should open on the right showing a live activity feed
>
> Options:
> - A) I can see the Side Panel — let's go!
> - B) I can see Chrome but can't find the extension
> - C) Something went wrong
> ```

**中文**：Chrome 已在 gstack 控制下启动。你应该能看到 Playwright 的 Chromium（不是你的常规 Chrome），页面顶部有一条金色发光线。

侧边栏扩展应该已经自动加载。要打开它：
1. 在工具栏中找到**拼图图标**（扩展）
2. 点击拼图 → 找到 **gstack browse** → 点击**图钉图标**
3. 点击工具栏中固定的 **gstack 图标**
4. 侧边栏应该在右侧打开，显示实时活动流

### "金色发光线"的作用

GStack Browser 在页面顶部有一条细细的金色渐变线，这是它和普通 Chromium 的视觉区别标志。用户通过这条线能立即认出 "这是被 gstack 控制的浏览器，不是我的个人 Chrome"。这个设计细节防止了用户混淆两个浏览器窗口。

### B 选项：手动加载扩展的处理

> **原文**：
> ```
> If B: Tell the user:
>
> > The extension is loaded into Playwright's Chromium at launch time, but sometimes
> > it doesn't appear immediately. Try these steps:
> >
> > 1. Type chrome://extensions in the address bar
> > 2. Look for "gstack browse" — it should be listed and enabled
> > 3. If it's NOT listed at all, click "Load unpacked" and navigate to:
> >    - Press Cmd+Shift+G in the file picker dialog
> >    - Paste this path: {EXTENSION_PATH}
> >    - Click Select
> ```

**中文**：扩展在启动时加载到 Playwright 的 Chromium 里，但有时不会立即显示。扩展通过 Playwright 的 `--load-extension` 参数加载，如果 Chromium 第一次启动时扩展目录不存在或路径错误，会静默失败。

### 手动加载扩展的操作流程

```
chrome://extensions 页面

情况 A：扩展已列出但未启用
  ├── 找到 "gstack browse"
  ├── 切换开关到 "启用"
  └── 返回普通页面，点拼图图标固定它

情况 B：扩展完全不在列表里
  ├── 点击右上角 "加载已解压的扩展程序"
  │   （需要打开 "开发者模式"）
  ├── 在文件选择器里：
  │   macOS: Cmd+Shift+G → 粘贴 EXTENSION_PATH
  │   Windows: 直接粘贴路径到地址栏
  ├── 点击 "选择"
  └── 扩展加载成功

EXTENSION_PATH 示例：
  macOS: /Users/you/.claude/skills/gstack/extension
  Windows: C:\Users\you\.claude\skills\gstack\extension
```

### C 选项：问题诊断流程

> **原文**：
> ```
> If C:
> 1. Run $B status and show the output
> 2. If the server is not healthy, re-run Step 0 cleanup + Step 1 connect
> 3. If the server IS healthy but the browser isn't visible, try $B focus
> 4. If that fails, ask the user what they see (error message, blank screen, etc.)
> ```

`$B focus` 命令的作用：把 GStack Browser 窗口带到前台（即使它被其他窗口遮挡）。这对于全屏工作的开发者很有用——浏览器可能已经打开，只是在当前窗口后面。

---

## 8. Step 4：Activity Feed 演示

> **原文**：
> ```
> ## Step 4: Demo
>
> After the user confirms the Side Panel is working, run a quick demo:
>
> $B goto https://news.ycombinator.com
>
> Wait 2 seconds, then:
>
> $B snapshot -i
>
> Tell the user: "Check the Side Panel — you should see the `goto` and `snapshot`
> commands appear in the activity feed. Every command Claude runs shows up here
> in real time."
> ```

**中文**：用户确认 Side Panel 正常工作后，运行一个快速演示。告知用户："检查 Side Panel——你应该能看到 `goto` 和 `snapshot` 命令出现在活动流中。Claude 运行的每个命令都会实时显示在这里。"

### Activity Feed 的数据流

```
Claude 执行：$B goto https://news.ycombinator.com

  Claude Code (主窗口)          GStack Browser (可视窗口)
       │                                   │
       │ HTTP POST                          │
       ├──────────────────────────────────►│
       │ /browse                           │  Playwright: page.goto("...")
       │ { action: "goto",                 │         │
       │   url: "https://..." }            │         ▼
       │                                   │  页面导航开始
       │                                   │  ┌─────────────────────────┐
       │                                   │  │ Hacker News 加载中...   │
       │                                   │  └─────────────────────────┘
       │                                   │         │ 完成
       │ 202 Accepted                      │         ▼
       │◄──────────────────────────────────┤  ┌─────────────────────────┐
       │                                   │  │ Hacker News 已加载      │
       │                                   │  └─────────────────────────┘
       │                                   │
       │                               Sidebar 扩展收到事件
       │                               ┌───────────────────────────────┐
       │                               │  Activity Feed:               │
       │                               │  ✓ 14:23:01 goto              │
       │                               │    https://news.ycombinator... │
       │                               │  ✓ 14:23:02 snapshot          │
       │                               └───────────────────────────────┘
```

### 为什么用 Hacker News 做演示？

- 反机器人检测**不强**（适合验证基础功能）
- 加载速度快（没有大量广告/追踪器）
- Garry Tan（gstack 的 "精神 founder"）是 YC 合伙人，HN 是 YC 的论坛
- 内容对开发者有意义（不会让人觉得这是随机选择）

---

## 9. Step 5：Sidebar Chat 介绍

> **原文**：
> ```
> ## Step 5: Sidebar chat
>
> After the activity feed demo, tell the user about the sidebar chat:
>
> > The Side Panel also has a chat tab. Try typing a message like "take a snapshot
> > and describe this page." A sidebar agent (a child Claude instance) executes your
> > request in the browser — you'll see the commands appear in the activity feed as
> > they happen.
> >
> > The sidebar agent can navigate pages, click buttons, fill forms, and read content.
> > Each task gets up to 5 minutes. It runs in an isolated session, so it won't
> > interfere with this Claude Code window.
> ```

**中文**：Side Panel 还有一个**聊天标签页**。输入 "take a snapshot and describe this page" 来试试。一个侧边栏 agent（子 Claude 实例）在浏览器里执行你的请求——你会在活动流中实时看到命令的出现。

侧边栏 agent 可以导航页面、点击按钮、填写表单、读取内容。每个任务最多 5 分钟。它在独立的会话中运行，不会干扰这个 Claude Code 窗口。

### Sidebar Chat 的架构

```
用户操作流：

  用户在 Side Panel 输入："fill in the login form and submit"
        │
        ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  Side Panel（Chrome 扩展 UI）                                    │
  │  POST /sidebar-task                                             │
  │  { "message": "fill in the login form and submit" }            │
  └────────────────────────────┬────────────────────────────────────┘
                               │ HTTP 到 localhost:34567
                               ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  Browse Server（gstack $B 进程）                                 │
  │                                                                 │
  │  接收任务 → 创建子 Claude 实例                                    │
  │                                                                 │
  │  ┌─────────────────────────────────────────────────────────┐   │
  │  │  Child Claude Agent（5 分钟限制）                        │   │
  │  │                                                         │   │
  │  │  理解任务："fill in login form and submit"              │   │
  │  │       │                                                 │   │
  │  │       ▼                                                 │   │
  │  │  $B snapshot → 查看当前页面结构                          │   │
  │  │  $B fill "#username" "test@example.com"                │   │
  │  │  $B fill "#password" "password123"                     │   │
  │  │  $B click 'button[type="submit"]'                      │   │
  │  └─────────────────────────────────────────────────────────┘   │
  │           │                                                     │
  │           │ 每个命令执行时，广播事件到 Sidebar                   │
  └───────────┼─────────────────────────────────────────────────────┘
              │
              ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  Side Panel Activity Feed（实时更新）                            │
  │  ✓ snapshot                                                     │
  │  ✓ fill #username                                               │
  │  ✓ fill #password                                               │
  │  ✓ click submit                                                 │
  │  → 已登录，跳转到 /dashboard                                     │
  └─────────────────────────────────────────────────────────────────┘
```

### "独立会话" 的技术含义

"不会干扰 Claude Code 窗口" 不只是描述——这是技术保证：

1. **独立的 Playwright page**：Sidebar agent 在一个独立的 browser page（标签页）里运行，和主 Claude Code 控制的 page 完全分开
2. **独立的 Agent 上下文**：Child Claude 有自己的对话历史，不会读取主窗口的对话内容
3. **5 分钟超时**：防止 Sidebar task 无限循环或长时间占用资源
4. **事件广播**：两者共享的只是 Activity Feed——Claude Code 的命令和 Sidebar 的命令都显示在同一个 Feed 里，但它们的执行是完全独立的

---

## 10. Step 6：后续操作指引

> **原文**：
> ```
> ## Step 6: What's next
>
> Tell the user:
>
> > You're all set! Here's what you can do with the connected Chrome:
> >
> > Watch Claude work in real time:
> > - Run any gstack skill (/qa, /design-review, /benchmark) and watch every
> >   action happen in the visible Chrome window + Side Panel feed
> > - No cookie import needed — the Playwright browser shares its own session
> >
> > Control the browser directly:
> > - Sidebar chat — type natural language in the Side Panel
> > - Browse commands — $B goto <url>, $B click <sel>, $B fill <sel> <val>,
> >   $B snapshot -i — all visible in Chrome + Side Panel
> >
> > Window management:
> > - $B focus — bring Chrome to the foreground anytime
> > - $B disconnect — close headed Chrome and return to headless mode
> ```

**中文**：你已经设置好了！以下是连接 Chrome 后可以做的事：

**实时观看 Claude 工作**：
- 运行任何 gstack 技能（`/qa`、`/design-review`、`/benchmark`），在可见的 Chrome 窗口 + Side Panel feed 里观看每个操作
- **不需要导入 Cookie**——Playwright 浏览器共享自己的会话

**直接控制浏览器**：
- Sidebar chat（自然语言）
- Browse 命令：`$B goto`、`$B click`、`$B fill`、`$B snapshot -i`

**窗口管理**：
- `$B focus`：随时把 Chrome 带到前台
- `$B disconnect`：关闭 headed Chrome，切回 headless 模式

### 为什么 headed 模式下不需要 Cookie 导入？

注意上面说的 "No cookie import needed"，这与 `/setup-browser-cookies` 的说明形成对比：

```
headed 模式（/open-gstack-browser）：
  Playwright 控制的 Chromium 有自己的持久化 profile
  ~/.gstack/chromium-profile/Cookies

  你可以：
  1. 在 headed 浏览器里手动登录（直接在可见窗口操作）
  2. 用 Sidebar Chat："go to staging.app.com and log in"
  3. 用 $B fill/click 完成登录

  Cookie 存在 profile 里，下次 $B connect 时依然有效

headless 模式（默认）：
  每次可以是全新会话 或 复用 profile
  但没有可见界面，所以无法"手动登录"

  你需要：
  /setup-browser-cookies → 从真实 Chrome 导入已有的 Cookie
```

---

## 11. Sidebar 扩展架构深度解析

### 扩展的三个组成部分

```
~/.claude/skills/gstack/extension/
├── manifest.json          → 扩展声明：权限、页面、background
├── background.js          → Service Worker：与 browse 服务通信
├── panel/
│   ├── panel.html         → Side Panel UI 的 HTML
│   ├── panel.js           → Side Panel 逻辑：Activity Feed + Chat
│   └── panel.css          → 样式（金色主题）
└── icons/
    └── icon.png           → 扩展图标（工具栏显示）
```

### Side Panel 的通信协议

```
三方通信：
  Playwright browse 服务 ←→ 扩展 background.js ←→ Side Panel UI

详细流程：

1. 扩展启动时：
   background.js → WebSocket 连接 ws://localhost:34567/sidebar
   连接成功后，browse 服务知道扩展已就位

2. Claude 执行 $B 命令时：
   $B goto https://example.com
   → browse 服务执行 Playwright 命令
   → browse 服务广播事件到 WebSocket
   → background.js 收到事件
   → postMessage 到 panel.js
   → Activity Feed 更新 UI

3. 用户在 Chat 里输入消息时：
   panel.js → postMessage 到 background.js
   background.js → HTTP POST 到 localhost:34567/sidebar-task
   browse 服务 → 创建 Child Claude Agent 执行任务
   Agent 执行期间 → 广播命令事件（同 Step 2）
   任务完成 → 返回结果文本到 Activity Feed
```

### 为什么用扩展而不是普通网页？

| 方案 | 实现方式 | 限制 |
|------|---------|------|
| 普通网页 | 在 Chrome 里打开 localhost:34567/ui | 跨域限制；无法 access browser tabs |
| Chrome 扩展 Side Panel | manifest.json 声明 side_panel | 原生 Chrome API；无跨域限制；持久化 |

Chrome 的 Side Panel API（Chrome 114+）允许扩展在浏览器窗口的**右侧**显示一个持久化的面板，这和普通的扩展弹窗不同——弹窗关闭就消失，Side Panel 保持可见。

### 扩展的加载方式

gstack 使用 Playwright 的 `--load-extension` 参数加载扩展：

```javascript
// browse/src/connect.ts（示意）
const context = await chromium.launchPersistentContext(userDataDir, {
  headless: false,
  args: [
    `--load-extension=${extensionPath}`,
    `--disable-extensions-except=${extensionPath}`,
    // ...
  ],
});
```

`--disable-extensions-except` 确保**只有** gstack 扩展被加载，不会意外加载用户在真实 Chrome 里安装的其他扩展（安全隔离）。

---

## 12. Anti-bot 隐身补丁

> **原文**：
> ```
> This launches GStack Browser (rebranded Chromium) in headed mode with:
> - Anti-bot stealth patches (sites like Google and NYTimes work without captchas)
> ```

**中文**：启动时包含反机器人隐身补丁（Google、NYTimes 等网站无需验证码即可访问）。

### 为什么 Playwright 默认会被检测到？

自动化工具在浏览器里留下了很多"指纹"：

```
1. navigator.webdriver = true
   → 所有 WebDriver 协议控制的浏览器都有这个标记
   → 反爬虫脚本的第一个检查点

2. window.chrome 对象异常
   → 真实 Chrome 有 window.chrome.runtime、window.chrome.csi 等
   → Playwright 的 Chromium 这些对象不完整或结构不同

3. navigator.plugins 为空
   → 真实用户的 Chrome 通常有 PDF Viewer、Native Client 等插件
   → 无头 Chromium 插件列表为空

4. Canvas 和 WebGL 指纹
   → 不同操作系统/GPU 的渲染结果有细微差异
   → 机器人通常在虚拟环境里，指纹特殊

5. 语言和时区
   → navigator.languages 和 Intl.DateTimeFormat 的一致性
   → 自动化环境常见不一致

6. 鼠标移动轨迹
   → 机器人的鼠标移动是直线，真人是曲线
```

### gstack 的隐身策略

gstack 使用了 `playwright-extra` + `puppeteer-extra-plugin-stealth` 的思路，在页面加载前注入 JavaScript 修改这些指纹：

```javascript
// 示意：页面初始化时注入
await page.addInitScript(() => {
  // 1. 删除 webdriver 标记
  Object.defineProperty(navigator, 'webdriver', {
    get: () => undefined,
  });

  // 2. 模拟真实 Chrome 的插件列表
  Object.defineProperty(navigator, 'plugins', {
    get: () => [
      { name: 'Chrome PDF Plugin', ... },
      { name: 'Chrome PDF Viewer', ... },
      { name: 'Native Client', ... },
    ],
  });

  // 3. 模拟 window.chrome
  window.chrome = {
    runtime: {
      onConnect: {},
      sendMessage: () => {},
      // ...
    },
    csi: () => {},
    loadTimes: () => ({
      ...
    }),
  };

  // 4. 修改 User Agent（与 launchOptions 里的 userAgent 配合）
  // ...
});
```

> **注意**：gstack 是 "headed mode"（可见窗口），使用真实的 Chromium 渲染引擎——这本身就大幅减少了被检测到的概率。headless 模式下渲染差异更明显。

### 隐身的局限性

| 站点 | 效果 | 原因 |
|------|------|------|
| Hacker News | ✅ 完全正常 | 没有反爬虫 |
| Google Search | ✅ 基本正常 | 主要检测 JS 指纹，gstack 修复了 |
| NYTimes | ✅ 可以访问 | 隐身补丁覆盖了主要检测点 |
| Cloudflare 5-second challenge | ⚠️ 部分场景有效 | 取决于具体 challenge 类型 |
| reCAPTCHA v3 | ❌ 可能触发 | 行为分析，难以完全欺骗 |
| 银行、支付 | ❌ 不推荐 | 高安全性场景，不适合自动化 |

---

## 13. Headed vs Headless 对比分析

### 核心参数对比

| 参数 | Headless 模式（默认） | Headed 模式（本技能） |
|------|---------------------|---------------------|
| 启动方式 | Playwright `launch()` | Playwright `launchPersistentContext()` |
| 可见窗口 | ❌ 无 | ✅ 有 |
| 扩展支持 | ❌ 不支持 | ✅ gstack Sidebar |
| Cookie 持久化 | 可选（取决于配置） | ✅ `~/.gstack/chromium-profile/` |
| 反机器人 | 基础修复 | 完整 stealth 补丁 |
| 资源消耗 | 低 | 较高（GUI 渲染） |
| OAuth 兼容性 | ❌ 部分提供商拒绝 | ✅ 与真实浏览器相同 |
| AI 可见调试 | ❌ 看不到操作 | ✅ 实时可见 |
| 启动速度 | 快（~1s） | 较慢（~3-5s） |

### 何时使用哪种模式

```
使用 Headless（默认，不运行本技能）：
  ✓ CI/CD 自动化测试
  ✓ 服务器环境（没有 GUI）
  ✓ 快速截图任务
  ✓ 不需要调试 AI 操作的场景
  ✓ 资源受限环境

使用 Headed（运行 /open-gstack-browser）：
  ✓ 调试：想看 AI 在做什么
  ✓ OAuth / 复杂身份验证
  ✓ 需要手动干预的场景（侧边栏聊天）
  ✓ 遇到 Cloudflare 或反爬虫拦截
  ✓ 视觉 QA：需要亲眼确认动画/布局
  ✓ 演示给他人看 AI 如何操作浏览器
```

### 决策流程图

```
需要浏览器测试？
        │
        ▼
有反爬虫问题 / 需要可视化 / 需要手动干预？
        │
       是 ──────────────────────────────► /open-gstack-browser
        │                                  （headed + sidebar）
       否
        │
        ▼
需要登录状态？
        │
       是 ──────────────────────────────► /setup-browser-cookies
        │                                  然后运行 /qa
       否
        │
        ▼
直接运行 /qa（headless 默认模式）
```

---

## 14. 与 setup-browser-cookies 的关系

这两个技能解决同一个根本问题（"让 AI 能访问需要认证的页面"），但从不同的角度：

### 两种路径对比

```
路径 A：Headed 模式（/open-gstack-browser）
┌───────────────────────────────────────────────────────────────┐
│                                                               │
│  /open-gstack-browser                                         │
│    → 启动可见 Chromium + Sidebar 扩展                         │
│    → 你在可见浏览器里手动登录（或通过 Sidebar Chat）            │
│    → Cookie 存储在 ~/.gstack/chromium-profile/                │
│    → 所有后续 $B 命令自动有登录状态                             │
│                                                               │
│  优点：不需要单独导入 Cookie；可以交互式登录                    │
│  缺点：需要可视窗口；OAuth 登录可能需要手动操作                 │
└───────────────────────────────────────────────────────────────┘

路径 B：Headless 模式（/setup-browser-cookies）
┌───────────────────────────────────────────────────────────────┐
│                                                               │
│  你在真实 Chrome 里正常使用（已经登录了各种网站）               │
│         ↓                                                     │
│  /setup-browser-cookies                                       │
│    → 从真实 Chrome 读取 Cookie                                │
│    → 解密并导入到 Playwright headless 会话                    │
│    → 所有后续 $B 命令自动有登录状态                             │
│                                                               │
│  优点：无需额外可视窗口；利用已有的登录状态                     │
│  缺点：某些网站 headless 模式会被拒绝；Cookie 可能过期          │
└───────────────────────────────────────────────────────────────┘
```

### 可以同时使用吗？

技术上可以，但通常不需要。如果你用了 `/open-gstack-browser`（CDP/headed 模式），`/setup-browser-cookies` 会在 CDP 检测步骤就停止并说 "不需要——你已经通过 CDP 连接到真实浏览器"。

唯一需要"两者结合"的场景是：
- 你用 `/open-gstack-browser` 启动了可视浏览器
- 但没有在里面手动登录
- 又想用 headless 模式跑 CI 测试
- 那就需要先切回 headless（`$B disconnect`），再运行 `/setup-browser-cookies`

---

## 15. 核心设计决策汇总

### 架构决策

| 设计决策 | 具体实现 | 背后原因 |
|---------|---------|---------|
| **持久化 profile 目录** | `~/.gstack/chromium-profile/` | 扩展加载需要；Cookie 跨会话持久化 |
| **固定端口 34567** | 扩展和 browse 服务硬编码 34567 | 零配置自动连接；不需要用户知道端口 |
| **品牌重定（GStack Browser）** | 自定义 User Agent + 金色渐变线 | 区分于用户的个人 Chrome；视觉标识 |
| **Pre-flight 清理** | 杀旧进程 + 删除 Singleton 锁文件 | 防止崩溃后的锁冲突 |
| **launchPersistentContext** | 非 `launch()` | 扩展支持的唯一方式 |
| **Sidebar 扩展（而非注入脚本）** | Chrome Extension + Side Panel API | 原生 UI 持久化；不被 CSP 阻断 |
| **Child Claude Agent（5 分钟）** | 独立子进程，有超时 | 隔离；防止无限循环 |
| **`--disable-extensions-except`** | 只加载 gstack 扩展 | 安全隔离；防止真实 Chrome 扩展的副作用 |

### 与 gstack 生态的集成位置

```
gstack 浏览器层次结构

Level 1: 纯 Headless（默认，无需任何技能）
  $B goto / click / fill / snapshot
  → 无窗口，最快，CI 友好

Level 2: Cookie 增强 Headless（/setup-browser-cookies）
  Level 1 + 真实浏览器的 Cookie
  → 无窗口，有登录状态

Level 3: Headed + Sidebar（/open-gstack-browser）★ 本技能
  Level 2 的能力 + 可见窗口 + Sidebar 扩展 + Child Agent
  → 最完整，调试 + 交互 + 可视化

Level 3 包含 Level 2 的所有能力，但资源消耗更高。
根据场景选择合适的层次。
```

### 典型使用场景

| 场景 | 推荐 | 原因 |
|------|------|------|
| CI/CD 自动化测试 | Level 1 (headless) | 无 GUI 环境，速度优先 |
| 本地快速 QA | Level 2 (cookie) | 需要登录状态，不需要可视化 |
| 调试 AI 操作 | Level 3 (headed) | 需要看到 AI 在做什么 |
| OAuth 登录测试 | Level 3 (headed) | OAuth 需要真实浏览器环境 |
| 遇到反爬虫 | Level 3 (headed) | 完整 stealth 补丁 |
| 给团队演示 AI 浏览 | Level 3 (headed) | 可视化效果最好 |
| 生产 canary 监控 | Level 1 or 2 | 服务器环境，轻量优先 |

**一句话总结**：`/open-gstack-browser` 是 gstack 浏览器能力的"完全体"——可见窗口 + Sidebar 扩展 + Child Agent + Anti-bot 隐身，让 AI 控制的浏览器不再是黑盒，而是一个你可以实时观察、随时介入的透明工作台。
