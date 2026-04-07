# `/setup-browser-cookies` 技能逐段中英对照注解

> 对应源文件：[`setup-browser-cookies/SKILL.md`](https://github.com/garrytan/gstack/blob/main/setup-browser-cookies/SKILL.md)（522 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## 目录

1. [为什么需要这个技能？](#1-为什么需要这个技能)
2. [Frontmatter（元数据区）](#2-frontmatter元数据区)
3. [Preamble 展开区](#3-preamble-展开区)
4. [CDP 模式检测](#4-cdp-模式检测)
5. [Cookie 工作原理](#5-cookie-工作原理)
6. [Step 1：找到 browse 二进制](#6-step-1找到-browse-二进制)
7. [Step 2：打开 Cookie 选择器 UI](#7-step-2打开-cookie-选择器-ui)
8. [Step 3：直接导入（可选）](#8-step-3直接导入可选)
9. [Step 4：验证导入结果](#9-step-4验证导入结果)
10. [平台注意事项](#10-平台注意事项)
11. [安全设计分析](#11-安全设计分析)
12. [与 QA 工作流的集成](#12-与-qa-工作流的集成)
13. [从零到认证会话的完整流程](#13-从零到认证会话的完整流程)
14. [核心设计决策汇总](#14-核心设计决策汇总)

---

## 1. 为什么需要这个技能？

### 问题根源：无头浏览器天生没有登录状态

```
真实浏览器（你日常用的 Chrome）         无头浏览器（Playwright）
┌─────────────────────────────┐         ┌────────────────────────────┐
│  Cookie Store               │         │  空的 Cookie Store          │
│  ┌──────────────────────┐   │         │  ┌──────────────────────┐   │
│  │ github.com: session  │   │  ≠≠≠≠   │  │ (空)                 │   │
│  │ jira.com: auth_token │   │         │  │                      │   │
│  │ staging.app: jwt     │   │         │  │                      │   │
│  └──────────────────────┘   │         │  └──────────────────────┘   │
│  你已经登录了所有这些网站     │         │  访问任何需要登录的页面     │
└─────────────────────────────┘         │  都会被重定向到登录页       │
                                        └────────────────────────────┘
```

当你运行 `/qa` 或 `/design-review` 对一个**需要登录才能访问**的 staging 环境或生产应用做测试，Playwright 启动的无头 Chromium 就像一个刚装好的全新浏览器——没有任何 Cookie，没有任何登录状态。

结果是：
- 测试覆盖到的全是登录页，而不是真正的功能页面
- 截图全是 "请先登录" 这类界面
- QA 报告完全没有意义

`/setup-browser-cookies` 解决这个问题：把你真实浏览器里的 Cookie 搬到 Playwright 的会话里。

### 两种不同的浏览器控制模式

gstack 有两种控制浏览器的方式，它们的 Cookie 行为完全不同：

| 模式 | 技术 | Cookie 情况 | 需要本技能？ |
|------|------|------------|------------|
| **CDP 模式** | Chrome DevTools Protocol | 直接控制你真实的 Chrome，Cookie 已经在了 | **不需要** |
| **Headless 模式** | Playwright 独立启动 Chromium | 全新空白会话，没有 Cookie | **需要** |

理解这个区别是理解本技能设计的基础。

---

## 2. Frontmatter（元数据区）

> **原文**：
> ```yaml
> ---
> name: setup-browser-cookies
> preamble-tier: 1
> version: 1.0.0
> description: |
>   Import cookies from your real Chromium browser into the headless browse session.
>   Opens an interactive picker UI where you select which cookie domains to import.
>   Use before QA testing authenticated pages. Use when asked to "import cookies",
>   "login to the site", or "authenticate the browser". (gstack)
> allowed-tools:
>   - Bash
>   - Read
>   - AskUserQuestion
> ---
> ```

**中文翻译**：

- **name**: 技能名称。用户输入 `/setup-browser-cookies` 触发。也可以说 "import cookies"、"login to the site"、"authenticate the browser"。
- **preamble-tier: 1**: 最精简的 Preamble 级别（共 4 级）。这个技能定位是**辅助工具**，不需要完整的 repo 分析、Search Before Building 等重型上下文——只需要基础的会话追踪和升级检查。
- **description**: 把你真实的 Chromium 浏览器里的 Cookie 导入到无头 browse 会话。打开一个交互式选择器 UI，让你选择要导入哪些域名的 Cookie。在对需要登录的页面做 QA 测试之前运行。
- **allowed-tools**: 只有 `Bash`、`Read`、`AskUserQuestion`。

> **设计原理：为什么没有 Edit/Write？**
>
> Cookie 导入是一个**运维操作**，不是代码变更。它修改的是 `~/.gstack/` 下的浏览器会话状态，而不是项目源文件。
> 允许 Edit/Write 反而会引入风险——AI 可能在你不知情的情况下修改项目文件。这是刻意的最小权限设计。

> **设计原理：为什么 preamble-tier 是 1 而不是 3？**
>
> Tier 1 只有基础的会话追踪、升级检查、遥测。不包括：
> - Repo 模式检测（这个技能不需要知道你在哪个分支）
> - Search Before Building（没有要搜索的东西）
> - AskUserQuestion 格式规范（交互很简单）
>
> 选 tier 1 是为了让技能尽快到达核心逻辑，减少前置开销。

---

## 3. Preamble 展开区

Preamble 包含所有 gstack 技能共享的初始化逻辑。对于 tier 1，关键部分是：

### 3.1 基础状态检查

> **原文（摘要）**：
> ```bash
> _BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
> echo "BRANCH: $_BRANCH"
> _PROACTIVE=$(~/.claude/skills/gstack/bin/gstack-config get proactive 2>/dev/null || echo "true")
> echo "PROACTIVE: $_PROACTIVE"
> source <(~/.claude/skills/gstack/bin/gstack-repo-mode 2>/dev/null) || true
> REPO_MODE=${REPO_MODE:-unknown}
> echo "REPO_MODE: $REPO_MODE"
> ```

这段 bash 在技能运行的最开始执行，输出类似：
```
BRANCH: main
PROACTIVE: true
REPO_MODE: solo
LEARNINGS: 3 entries loaded
```

**为什么要检查这些？**

- `BRANCH`：会话追踪需要知道在哪个分支
- `PROACTIVE`：如果用户关闭了主动建议，不能在 Cookie 导入后自动建议跑 `/qa`
- `REPO_MODE`：`solo` 模式下可以主动发现并修复问题；`collaborative` 模式下只汇报

### 3.2 遥测（Telemetry）

```bash
if [ "$_TEL" != "off" ]; then
echo '{"skill":"setup-browser-cookies","ts":"...","repo":"..."}'  >> ~/.gstack/analytics/skill-usage.jsonl
fi
```

遥测分三个级别：
- `community`：发送技能使用统计 + 时长，有稳定设备 ID
- `anonymous`：只计数，无法关联会话
- `off`：完全不发送

**关键点**：遥测**永远不发送**代码、文件路径、仓库名。

### 3.3 Learnings（历史经验复用）

```bash
_LEARN_FILE="${GSTACK_HOME:-$HOME/.gstack}/projects/${SLUG:-unknown}/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" 2>/dev/null | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries loaded"
  if [ "$_LEARN_COUNT" -gt 5 ] 2>/dev/null; then
    ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 3 2>/dev/null || true
  fi
fi
```

如果这个项目之前运行过这个技能，会加载历史经验。比如：
- "上次在这个项目里，github.com 的 Cookie 导入需要点击 Keychain 的 Always Allow"
- "这个项目的 staging 环境用 comet 浏览器的 Cookie"

这让 AI 在每次运行时不必重新摸索同样的细节。

---

## 4. CDP 模式检测

> **原文**：
> ```bash
> # CDP mode check
> $B status 2>/dev/null | grep -q "Mode: cdp" && echo "CDP_MODE=true" || echo "CDP_MODE=false"
>
> # If CDP_MODE=true:
> # Tell the user: "Not needed — you're connected to your real browser via CDP.
> # Your cookies and sessions are already available." and stop.
> ```

**中文**：首先检查 browse 是否已经连接到用户的真实浏览器。如果 `CDP_MODE=true`：告知用户"不需要 Cookie 导入——你已经通过 CDP 连接到真实浏览器，Cookie 和会话已经可用。"然后停止。

### CDP 模式 vs Headless 模式的根本区别

```
CDP 模式（通过 /open-gstack-browser 或 connect-chrome）：
┌──────────────────────────────────────────────────────────┐
│  你的真实 Chrome 进程                                     │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Chrome DevTools Protocol (CDP) WebSocket          │  │
│  │  ws://localhost:9222                               │  │
│  └───────────────────────┬────────────────────────────┘  │
│                          │ 双向控制                        │
│  ┌───────────────────────▼────────────────────────────┐  │
│  │  Playwright CDP Client (gstack $B)                 │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  结果：直接访问你的 Cookie Store，无需导入                 │
└──────────────────────────────────────────────────────────┘

Headless 模式（默认）：
┌──────────────────────────────────────────────────────────┐
│  Playwright 启动的独立 Chromium 进程                      │
│  ┌────────────────────────────────────────────────────┐  │
│  │  全新空白 Cookie Store                              │  │
│  │  与你的 Chrome 完全隔离                             │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  结果：没有任何登录状态，需要手动导入 Cookie               │
└──────────────────────────────────────────────────────────┘
```

### 为什么把 CDP 检查放在第一步？

这是**防御性设计**。用户可能不知道自己当前是什么模式：

1. 如果刚运行过 `/open-gstack-browser`，已经是 CDP/headed 模式了，不需要做任何事
2. 如果是第一次使用，是默认的 headless 模式，需要导入 Cookie
3. 如果检查失败（browse 没有启动），后续命令会返回有意义的错误

跳过这个检查可能导致：在 CDP 模式下重复导入 Cookie，造成 Cookie 冲突或被覆盖。

---

## 5. Cookie 工作原理

> **原文**：
> ```
> ## How it works
>
> 1. Find the browse binary
> 2. Run `cookie-import-browser` to detect installed browsers and open the picker UI
> 3. User selects which cookie domains to import in their browser
> 4. Cookies are decrypted and loaded into the Playwright session
> ```

**中文**：
1. 找到 browse 二进制
2. 运行 `cookie-import-browser` 检测已安装的浏览器，打开选择器 UI
3. 用户在浏览器里选择要导入哪些域名的 Cookie
4. Cookie 被解密并加载到 Playwright 会话中

### Cookie 的存储和加密

不同平台的 Cookie 存储方式不同，解密机制也不同：

| 平台 | Cookie 存储位置 | 加密方式 |
|------|---------------|---------|
| macOS | `~/Library/Application Support/Google/Chrome/Default/Cookies` | AES-128-CBC，密钥存 Keychain |
| Linux | `~/.config/google-chrome/Default/Cookies` | v10: AES-128-CBC (固定密钥) / v11: libsecret |
| Windows | `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Network\Cookies` | DPAPI（Data Protection API） |

### Cookie 传递的技术流程

```
真实浏览器的 Cookie 文件（SQLite）
        │
        │ 1. gstack 读取 Cookies 数据库
        ▼
┌───────────────────────┐
│  SQLite 查询          │
│  SELECT * FROM cookies│
│  WHERE host_key=?     │
└───────────┬───────────┘
            │
            │ 2. 解密 Cookie 值
            ▼
┌───────────────────────┐
│  平台解密              │
│  macOS: Keychain      │
│  Linux: libsecret     │
│  Windows: DPAPI       │
└───────────┬───────────┘
            │
            │ 3. 通过 Playwright API 注入
            ▼
┌───────────────────────┐
│  context.addCookies() │
│  (Playwright API)     │
└───────────┬───────────┘
            │
            │ 4. 保存到 gstack 会话状态
            ▼
┌───────────────────────┐
│  ~/.gstack/comet-     │
│  session/cookies.json │
└───────────────────────┘
```

### 为什么叫 "comet"？

`comet` 是 gstack 内部对 "持久 Cookie 存储" 的代号。`$B cookie-import-browser comet --domain github.com` 里的 `comet` 就是把 Cookie 写入这个持久存储，而不是临时会话。

---

## 6. Step 1：找到 browse 二进制

> **原文**：
> ```bash
> ## SETUP (run this check BEFORE any browse command)
>
> _ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
> B=""
> [ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="$_ROOT/.claude/skills/gstack/browse/dist/browse"
> [ -z "$B" ] && B=~/.claude/skills/gstack/browse/dist/browse
> if [ -x "$B" ]; then
>   echo "READY: $B"
> else
>   echo "NEEDS_SETUP"
> fi
> ```

**中文**：设置（在任何 browse 命令之前运行此检查）。

这个检查实现了一个**优先级搜索**：

```
优先级 1：项目级别的 gstack 安装
  <git-root>/.claude/skills/gstack/browse/dist/browse
  （团队模式，vendored 安装）
        ↓ 如果不存在
优先级 2：用户级别的 gstack 安装
  ~/.claude/skills/gstack/browse/dist/browse
  （全局安装，个人使用）
        ↓ 如果都不存在
输出 "NEEDS_SETUP"
  → 提示用户运行 ./setup
```

### NEEDS_SETUP 处理流程

> **原文**：
> ```
> If `NEEDS_SETUP`:
> 1. Tell the user: "gstack browse needs a one-time build (~10 seconds). OK to proceed?" Then STOP and wait.
> 2. Run: `cd <SKILL_DIR> && ./setup`
> 3. If `bun` is not installed:
>    BUN_VERSION="1.3.10"
>    BUN_INSTALL_SHA="bab8acfb046aac8c72407bdcce903957665d655d7acaa3e11c7c4616beae68dd"
>    # ...验证 SHA256 后再安装
> ```

**中文**：如果 `NEEDS_SETUP`：
1. 告知用户 "gstack browse 需要一次构建（约 10 秒）。可以继续吗？" 然后**停止等待**。
2. 运行：`cd <SKILL_DIR> && ./setup`
3. 如果 `bun` 没有安装，先验证 SHA256 再安装

> **设计原理：为什么要验证 bun 安装脚本的 SHA256？**
>
> 这是**供应链安全**。`curl | bash` 是危险的——如果 bun.sh 被黑或 CDN 被劫持，你会执行恶意代码。
> 通过预置已知的 SHA256 (`bab8acfb...`)，gstack 验证下载的安装脚本没有被篡改。
> 这是一个"trust on first use + pin the hash"的安全模型。

---

## 7. Step 2：打开 Cookie 选择器 UI

> **原文**：
> ```bash
> ### 2. Open the cookie picker
>
> $B cookie-import-browser
>
> This auto-detects installed Chromium browsers and opens an interactive picker
> UI in your default browser where you can:
> - Switch between installed browsers
> - Search domains
> - Click "+" to import a domain's cookies
> - Click trash to remove imported cookies
>
> Tell the user: "Cookie picker opened — select the domains you want to import
> in your browser, then tell me when you're done."
> ```

**中文**：这个命令自动检测已安装的 Chromium 浏览器，并在你的默认浏览器里打开一个交互式选择器 UI，你可以：
- 在已安装的浏览器之间切换
- 搜索域名
- 点击 "+" 导入某个域名的 Cookie
- 点击垃圾桶图标删除已导入的 Cookie

告知用户："**Cookie 选择器已打开——在浏览器里选择要导入的域名，完成后告诉我。**"

### Cookie 选择器 UI 的工作原理

```
用户的默认浏览器打开 http://localhost:34567/cookies
         │
         │ HTTP 请求
         ▼
┌─────────────────────────────────────────────────────────┐
│  gstack browse 服务器（内嵌 HTTP 服务）                  │
│  port: 34567                                            │
│                                                         │
│  GET /cookies                                           │
│  → 渲染 Cookie 选择器 HTML 页面                          │
│                                                         │
│  已安装的浏览器：                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  [Chrome] [Brave] [Edge] [Chromium]             │   │
│  │  当前选中: Chrome                               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  域名列表（只显示域名 + Cookie 数量，不暴露值）：          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  🔍 搜索域名...                                 │   │
│  │  github.com          (42 cookies)  [+] [🗑]    │   │
│  │  google.com          (18 cookies)  [+] [🗑]    │   │
│  │  staging.myapp.com   (7 cookies)   [+] [🗑]    │   │
│  │  jira.atlassian.net  (23 cookies)  [+] [🗑]    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  POST /cookies/import                                   │
│  → 解密并写入 Playwright 会话                            │
└─────────────────────────────────────────────────────────┘
```

### 为什么用 Web UI 而不是命令行参数？

| 交互方式 | 优点 | 缺点 |
|---------|------|------|
| 命令行参数 `--domain github.com` | 可脚本化 | 需要提前知道域名；不直观 |
| 交互式 Web UI | 直观；可以看到有哪些域名；支持搜索 | 需要打开浏览器 |

gstack 默认选择 Web UI，是因为大多数用户不知道他们的 staging 环境用的是什么域名。

> **注意**：Cookie 选择器和 browse 服务器共用同一个端口（`34567`），不需要额外启动进程。

---

## 8. Step 3：直接导入（可选）

> **原文**：
> ```
> ### 3. Direct import (alternative)
>
> If the user specifies a domain directly (e.g., `/setup-browser-cookies github.com`),
> skip the UI:
>
> $B cookie-import-browser comet --domain github.com
>
> Replace `comet` with the appropriate browser if specified.
> ```

**中文**：如果用户直接指定了域名（比如 `/setup-browser-cookies github.com`），跳过 UI：

```bash
$B cookie-import-browser comet --domain github.com
```

用用户指定的浏览器替换 `comet`（如果指定了的话）。

### 何时使用直接导入？

| 场景 | 推荐方式 |
|------|---------|
| 知道具体的域名，需要自动化 | 直接导入：`$B cookie-import-browser comet --domain staging.app.com` |
| 不确定有哪些域名，需要探索 | UI 选择器：`$B cookie-import-browser` |
| CI/CD 脚本化场景 | 直接导入 |
| 日常开发调试 | UI 选择器更直观 |

### 浏览器标识符

`comet` 是 gstack 对 "持久存储目标" 的内部命名，不是浏览器名。可以指定不同的源浏览器：

```bash
# 从 Chrome 导入
$B cookie-import-browser chrome --domain github.com

# 从 Brave 导入
$B cookie-import-browser brave --domain github.com

# 从 Edge 导入
$B cookie-import-browser edge --domain github.com
```

---

## 9. Step 4：验证导入结果

> **原文**：
> ```
> ### 4. Verify
>
> After the user confirms they're done:
>
> $B cookies
>
> Show the user a summary of imported cookies (domain counts).
> ```

**中文**：用户确认完成后，运行验证命令，向用户展示已导入 Cookie 的摘要（域名数量）。

### 验证输出示例

```
$ $B cookies

Imported cookies:
  github.com: 42 cookies
  staging.myapp.com: 7 cookies
  jira.atlassian.net: 23 cookies

Total: 72 cookies across 3 domains
Session: active (headless mode)
```

> **设计原理：为什么只显示数量而不显示值？**
>
> Cookie 值包含会话令牌、JWT、CSRF token 等敏感凭据。显示这些值等于把你的登录凭证打印到终端——任何看到这个终端的人都可以用这些值登录你的账号。
>
> 只显示"域名 + 数量"是最小权限原则：AI 只需要知道导入是否成功，不需要知道具体的 Cookie 值。

### 导入后即时生效

Cookie 写入后立即在所有后续 `$B` 命令中生效，不需要重启浏览器会话：

```bash
$B cookie-import-browser comet --domain github.com
# 立即有效
$B goto https://github.com/settings  # 直接进入设置页，无需登录
$B snapshot -i  # 截图显示已登录状态
```

---

## 10. 平台注意事项

> **原文**：
> ```
> ## Notes
>
> - On macOS, the first import per browser may trigger a Keychain dialog —
>   click "Allow" / "Always Allow"
> - On Linux, `v11` cookies may require `secret-tool`/libsecret access;
>   `v10` cookies use Chromium's standard fallback key
> - Cookie picker is served on the same port as the browse server (no extra process)
> - Only domain names and cookie counts are shown in the UI — no cookie values are exposed
> - The browse session persists cookies between commands, so imported cookies work immediately
> ```

**中文**：
- macOS：第一次导入某个浏览器的 Cookie 时，可能会弹出 Keychain 对话框——点击 "Allow"（允许）或 "Always Allow"（总是允许）
- Linux：v11 格式的 Cookie 可能需要 `secret-tool`/libsecret 访问；v10 格式的 Cookie 使用 Chromium 标准回退密钥
- Cookie 选择器在与 browse 服务器相同的端口提供服务（不需要额外进程）
- UI 中只显示域名和 Cookie 数量——不暴露 Cookie 的具体值
- browse 会话在命令之间持久化 Cookie，导入后立即生效

### 平台兼容性详解

#### macOS：Keychain 权限

```
首次导入 Chrome Cookie 时：
┌──────────────────────────────────────────────────────────┐
│  macOS Keychain 权限请求                                  │
│                                                          │
│  "gstack browse" 想要访问 Keychain 中的密钥              │
│  （Chrome Safe Storage）                                 │
│                                                          │
│  [取消]  [允许]  [总是允许]                               │
└──────────────────────────────────────────────────────────┘

推荐选择 "总是允许" — 这样后续导入就不会再弹出。
选 "允许" 每次都会弹出，很烦人。
选 "取消" Cookie 解密失败。
```

#### Linux：两种 Cookie 加密格式

| 版本 | 加密方式 | gstack 处理 |
|------|---------|------------|
| v10 (旧) | AES-128-CBC，固定密钥 `peanuts` | 直接解密，无需额外工具 |
| v11 (新) | AES-128-CBC，密钥存 libsecret | 需要 `secret-tool` / `libsecret` 库 |

如果 v11 Cookie 解密失败，安装 libsecret：
```bash
# Ubuntu/Debian
sudo apt install libsecret-tools

# Arch Linux
sudo pacman -S libsecret
```

#### Windows：DPAPI

Windows 的 Cookie 加密使用 DPAPI（Data Protection API），密钥绑定到当前 Windows 用户账号。gstack 自动处理，无需额外配置。

---

## 11. 安全设计分析

### 哪些 Cookie 应该导入？

```
✅ 推荐导入：
  - staging.myapp.com     (你自己的 staging 环境)
  - app.company.internal  (内部工具)
  - github.com            (如果要测试 OAuth 集成)

⚠️ 谨慎导入：
  - google.com            (账号关联复杂，可能影响 API quota)
  - facebook.com          (触发安全检测风险)

❌ 不推荐导入：
  - 银行、支付网站         (高价值目标，不必要)
  - 邮件服务              (没有 QA 测试需求)
  - 社交媒体              (账号安全风险)
```

### gstack 的安全边界

gstack 对 Cookie 数据的访问有以下限制：

| 访问类型 | gstack 是否有访问 |
|---------|----------------|
| Cookie 域名 | ✅ 是（用于展示选择器） |
| Cookie 数量 | ✅ 是（用于验证导入） |
| Cookie 值（原始） | ✅ 是（解密后注入 Playwright，但不向 AI 展示） |
| Cookie 值（向 AI 展示） | ❌ 否（AI 只看到数量） |
| Cookie 值（发送到远程） | ❌ 否（遥测不包含 Cookie 数据） |

> **关键安全保证**：Claude（AI 本体）**永远看不到 Cookie 的具体值**。`$B cookies` 命令返回的只是摘要。即使遥测开启，也只记录技能名称和时长，绝不记录 Cookie 数据。

### Cookie 的生命周期

```
导入时
  $B cookie-import-browser comet --domain github.com
        │
        ▼ 写入
  ~/.gstack/comet-session/
        │
        ├── 所有 $B 命令期间持久有效
        ├── 技能运行结束后仍然保留（下次 $B 命令继续使用）
        │
        ▼ 清除（手动）
  $B cookies clear
```

---

## 12. 与 QA 工作流的集成

### 标准 QA 工作流（需要登录的应用）

```
┌─────────────────────────────────────────────────────────────┐
│                   完整工作流                                 │
│                                                             │
│  第一步（只需一次）：                                        │
│  /setup-browser-cookies                                     │
│         │                                                   │
│         │  选择 staging.myapp.com                           │
│         ▼                                                   │
│  Cookie 已导入到 Playwright 会话                             │
│         │                                                   │
│  第二步（每次测试时运行）：                                   │
│         │                                                   │
│         ▼                                                   │
│  /qa                                                        │
│    │                                                        │
│    ├── $B goto https://staging.myapp.com/dashboard          │
│    │   ↳ 直接进入 dashboard（已登录）                       │
│    │                                                        │
│    ├── $B goto https://staging.myapp.com/admin/users        │
│    │   ↳ 直接进入管理页（已登录）                           │
│    │                                                        │
│    └── $B snapshot -i                                       │
│        ↳ 截图显示真实界面                                    │
└─────────────────────────────────────────────────────────────┘
```

### Cookie 持久化说明

一旦导入，Cookie 在以下操作间持久有效：

- ✅ 同一 Claude 会话的多个 `$B` 命令
- ✅ 不同的 gstack 技能（`/qa`、`/design-review`、`/benchmark` 共享）
- ✅ 跨 Claude 会话（存储在 `~/.gstack/` 下，不是内存）
- ❌ 当真实浏览器的 Cookie 过期后，需要重新导入

### 与其他技能的集成点

```
/setup-browser-cookies  （导入登录状态）
        ↓
  ┌─────────────┬──────────────────┬─────────────────┐
  ▼             ▼                  ▼                 ▼
/qa           /design-review   /benchmark        /canary
测试登录后     截图登录后        测量登录后         监控生产
的功能页面     的真实界面        的性能数据         环境健康
```

---

## 13. 从零到认证会话的完整流程

### 场景：第一次对需要登录的 staging 环境做 QA

```
前提条件：
  ✓ 你已经在真实 Chrome 里登录了 staging.myapp.com
  ✓ gstack 已安装（~/.claude/skills/gstack/）
  ✓ 没有运行 /open-gstack-browser（所以是 headless 模式）

Step 1: 运行技能
  你：/setup-browser-cookies

Step 2: CDP 模式检查（自动）
  gstack: 检查是否在 CDP 模式...
  结果：CDP_MODE=false（headless 模式）
  继续导入流程。

Step 3: 检查 browse 二进制（自动）
  gstack: 检查 browse 是否就绪...
  结果：READY: ~/.claude/skills/gstack/browse/dist/browse

Step 4: 打开 Cookie 选择器
  gstack 执行：$B cookie-import-browser
  gstack 告知你："Cookie 选择器已打开——在浏览器里选择要导入的域名，完成后告诉我。"

  你的默认浏览器打开：http://localhost:34567/cookies
  界面显示所有 Chrome 里的域名

Step 5: 你选择域名（在浏览器里操作）
  你点击 "staging.myapp.com" 旁边的 "+"
  Cookie 选择器显示："已导入 staging.myapp.com (12 cookies)"
  你回到 Claude 说："好了"

Step 6: 验证（自动）
  gstack 执行：$B cookies
  输出：
    Imported cookies:
      staging.myapp.com: 12 cookies
    Total: 12 cookies across 1 domain

Step 7: 完成，可以运行 QA
  gstack："Cookie 导入成功！现在可以运行 /qa 测试已登录状态的页面了。"

  你：/qa
  QA 直接进入 dashboard 页面，所有测试都在已登录状态下运行
```

### 故障排查

| 症状 | 原因 | 解决方案 |
|------|------|---------|
| Cookie 选择器打开但列表为空 | browse 服务没有读到浏览器 Cookie | 确认 Chrome 已关闭（部分平台需要 Chrome 未运行才能读 Cookie） |
| macOS 弹出 Keychain 但拒绝后 Cookie 导入失败 | Keychain 权限被拒绝 | 重新运行，这次选择 "Always Allow" |
| Linux: "v11 cookies require libsecret" | 缺少 libsecret | `sudo apt install libsecret-tools` |
| 导入后访问网站仍然跳转登录页 | Cookie 域名不匹配 | 检查域名：staging.myapp.com 的 Cookie 不能用于 app.myapp.com |
| CDP_MODE=true 但没有登录状态 | 连接的是 headless Chromium 而非真实 Chrome | 运行 `/open-gstack-browser` 连接真实 Chrome，或切回 headless 模式导入 Cookie |

---

## 14. 核心设计决策汇总

### 设计原则

| 设计决策 | 具体实现 | 背后原因 |
|---------|---------|---------|
| **CDP 优先检查** | 运行前检测当前模式 | CDP 模式不需要导入，避免多余操作或 Cookie 冲突 |
| **图形化选择器** | Web UI 而非命令行 | 用户不知道域名列表；可视化选择更安全（防止误选） |
| **不暴露 Cookie 值** | AI 只看到域名 + 数量 | 最小权限：AI 完成任务不需要看 Cookie 值 |
| **SHA256 验证** | 验证 bun 安装脚本 | 供应链安全，防止 curl \| bash 被劫持 |
| **共享端口** | Cookie 选择器和 browse 同用 34567 | 无需额外进程，减少资源占用 |
| **持久化存储** | Cookie 写入 `~/.gstack/` | 跨会话有效，不用每次导入 |
| **Preamble tier 1** | 最轻量前置 | 导入 Cookie 是辅助工具，不需要完整 repo 上下文 |
| **直接导入模式** | `--domain` 参数跳过 UI | 满足自动化/脚本化场景 |

### 与类似工具对比

| 工具 | 方式 | 安全性 | 可用性 |
|------|------|--------|--------|
| Playwright `addCookies()` | 手动传入 JSON | 高 | 低（需手动导出 Cookie） |
| puppeteer-extra-plugin-stealth | 自动处理指纹，非 Cookie | 中 | 中 |
| **gstack setup-browser-cookies** | 半自动 UI + 解密 | **高**（不暴露值） | **高**（可视化选择） |
| 手动复制粘贴 Cookie | 完全手动 | 低（明文传递） | 低 |

### 完整工具链位置

```
gstack 浏览器工具链
├── /open-gstack-browser    → 启动 headed（可视）浏览器 + Sidebar 扩展
│   └── CDP 模式：直接控制你的 Chrome，Cookie 自动共享
│
├── /setup-browser-cookies  → 本技能：把真实浏览器 Cookie 导入 headless 会话
│   └── Headless 模式：Playwright 独立 Chromium，需要手动导入 Cookie
│
├── /qa                     → QA 测试（使用上述两种模式之一）
├── /design-review          → 可视化审查（使用上述两种模式之一）
└── /benchmark              → 性能测试（使用上述两种模式之一）
```

**一句话总结**：`/setup-browser-cookies` 是无头浏览器测试的"身份验证桥梁"——把你日常浏览器里的登录状态安全地搬到 AI 控制的 Playwright 会话里，让 QA 能测试真实用户看到的界面。
