# Browse 守护进程深度解读

> 对应源码：[`browse/src/`](https://github.com/garrytan/gstack/tree/main/browse/src)
> gstack 的"眼睛"——所有浏览器交互的基础层。

---

## 架构概览

Browse 不是"每次打开一个浏览器"——它是一个**长驻守护进程**，管理一个持久的 Chromium 实例。

```
┌──────────────────────────────────────────────────────┐
│  CLI (cli.ts)                                         │
│  ├─ 读取状态文件 .gstack/browse.json                 │
│  ├─ 进程活着？→ 发 HTTP 请求                        │
│  └─ 进程死了？→ 启动新 server（detached）           │
└──────────────────────┬───────────────────────────────┘
                       │ HTTP POST /command
                       ▼
┌──────────────────────────────────────────────────────┐
│  Server (server.ts, 1700+ 行)                        │
│  ├─ Bun HTTP server                                  │
│  ├─ Bearer token 认证                                │
│  ├─ 命令分发 → read/write/meta handlers             │
│  ├─ Activity SSE 流（实时事件推送）                  │
│  ├─ 30 分钟空闲自动关闭                             │
│  └─ 状态原子写入（.tmp → rename）                   │
└──────────────────────┬───────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│  BrowserManager (browser-manager.ts, 900+ 行)        │
│  ├─ Chromium 生命周期管理                            │
│  ├─ Tab 管理（新建/切换/关闭）                       │
│  ├─ @ref 引用系统（@e1, @e2, @c1...）               │
│  ├─ Frame 上下文切换                                 │
│  ├─ Cookie/Storage 状态捕获                          │
│  └─ Headed 模式：反检测 + 扩展加载 + 品牌化        │
└──────────────────────────────────────────────────────┘
```

---

## 为什么是守护进程？

传统无头浏览器工具每次命令都启动新实例：

```
传统：命令 → 启动 Chromium → 执行 → 关闭    （~2-5秒/命令）
Browse：命令 → HTTP 请求 → 已有实例执行       （~100ms/命令）
```

**持久状态的好处**：
- Cookie/登录状态在命令间保持
- Tab 在命令间保持（可以在多个页面间切换）
- Console/Network 日志持续收集（环形缓冲区 50,000 条）
- 没有冷启动开销

---

## 端口和进程发现

```
启动时：
  随机端口 10000-60000（或 BROWSE_PORT 环境变量）
  状态写入 .gstack/browse.json:
    { pid, port, token, startedAt, mode }

CLI 每次调用：
  1. 读 browse.json
  2. PID 还活着？→ HTTP GET /health
  3. 健康？→ POST /command
  4. 死了/不健康？→ kill 旧进程 → 启动新 server
```

**状态文件原子写入**：先写 `.tmp` 文件再 rename，防止进程崩溃时损坏状态文件。

---

## 命令体系

**65 个命令**分三类：

| 类别 | 数量 | 示例 | 特点 |
|------|------|------|------|
| READ (19) | text, html, links, console, css | 只读，不改变页面状态 |
| WRITE (24) | goto, click, fill, scroll, cleanup | 改变页面状态 |
| META (22) | tabs, screenshot, snapshot, diff | 管理级操作 |

**命令分发**（server.ts handleCommand）：
1. 解析 JSON body: `{command, args[], tabId?}`
2. 可选 tab 切换（不抢焦点）
3. watch 模式下阻止 mutation
4. 发射 activity 事件 `command_start`
5. 路由到对应 handler
6. 不受信任内容包裹 `--- BEGIN/END UNTRUSTED EXTERNAL CONTENT ---`
7. 发射 activity 事件 `command_end`

---

## Snapshot 系统（核心创新）

Snapshot 是 Browse 最重要的能力——把页面变成 AI 可读的结构化文本。

```
$B snapshot          → ARIA 树 + @ref 标签
$B snapshot -i       → 只保留可交互元素
$B snapshot -D       → 与上次 snapshot 的 unified diff
$B snapshot -a       → 截图 + 红色标注框
$B snapshot -c       → 移除空结构节点
```

**@ref 引用系统**：
```
@e1  button "Submit"
@e2  link "Home"
@c1  div.dropdown-trigger  (cursor:pointer 检测到)

后续命令可以直接用：
$B click @e1      → 点击 Submit 按钮
$B fill @e3 "hello" → 填写第三个元素
```

**为什么不用 CSS 选择器？**

CSS 选择器在 DOM 变化后容易失效。@ref 基于 ARIA 语义树，
更稳定——按钮改了 class 名不影响 @ref。

**Cursor-Interactive 扫描**（snapshot.ts 236-337 行）：

不是所有可点击元素都有正确的 ARIA role。有些用 `cursor:pointer` 或 `onclick` 实现。
Cursor-Interactive 扫描检测这些"隐式交互元素"，标记为 `@c1, @c2...`。

---

## Headed 模式 vs Headless 模式

| | Headless（默认） | Headed |
|--|-----------------|--------|
| UI | 无 | 有窗口，用户可看到 |
| 速度 | 更快 | 正常 |
| 扩展 | 不加载 | 加载 gstack sidebar |
| 对话框 | 自动接受 | 用户处理 |
| Cookie | 每次新 context | 持久 profile |
| 反检测 | 无需 | 全套 stealth |

**Headed 模式的反检测**（browser-manager.ts 344-388 行）：
- 伪造 `navigator.plugins`（PDF Viewer 等）
- 覆盖 `navigator.languages` 为 `['en-US', 'en']`
- 清理 CDP 痕迹（`cdc_*`, `__webdriver`）
- 通知权限 API 返回 `prompt`
- 自定义 UA 带 "GStackBrowser"
- macOS 替换 Dock 图标 + Info.plist

**视觉指示器**：页面顶部的琥珀色渐变条，提醒这是 AI 控制的浏览器。

---

## 环形缓冲区（buffers.ts）

Console/Network/Dialog 日志用 O(1) 环形缓冲区存储：

```
容量：50,000 条/缓冲区
写入：O(1)（覆盖最旧条目）
读取：O(n)
刷盘：定时异步 + 优雅关闭时
缺口检测：totalAdded 计数器，客户端可知道是否丢条目
```

**为什么不用无限数组？** 无头浏览器可能运行数小时，console.log 可能刷屏。
环形缓冲区保证内存恒定。

---

## Activity 流（activity.ts）

所有命令执行都产生 Activity 事件，通过 SSE（Server-Sent Events）实时推送。

```
POST /command → command_start 事件 → 执行 → command_end 事件
     ↓                                            ↓
GET /activity/stream?after=123  ← SSE 推送到 sidebar
```

**隐私过滤**（activity.ts 47-110 行）：
密码、token、API key 在推送前被脱敏。

---

## 安全边界

| 机制 | 位置 | 目的 |
|------|------|------|
| Bearer Token | 启动时生成 UUID | 防止未授权访问 |
| 不受信任内容包裹 | commands.ts 52-58 | 标记第三方页面内容 |
| 路径验证 | read/write-commands.ts | 词法检查 + symlink 解析 |
| URL 验证 | url-validation.ts | 阻止 javascript: 和 file:// |
| Activity 脱敏 | activity.ts | 密码/token 不进 SSE |
| CSP 兼容 | snapshot.ts | cursor-interactive 扫描 try-catch |

---

## HTTP 端点总览

| 端点 | 方法 | 认证 | 重置空闲？ | 用途 |
|------|------|------|-----------|------|
| `/command` | POST | 是 | 是 | 执行命令 |
| `/health` | GET | 否 | 否 | 健康检查 |
| `/refs` | GET | 是 | 否 | 当前 @ref 映射 |
| `/activity/stream` | GET | 是 | 否 | SSE 实时事件 |
| `/sidebar-*` | GET/POST | 是 | 否 | Sidebar 交互 |
| `/inspector/*` | GET/POST | 是 | 否 | CSS 检查器 |
| `/cookie-picker/*` | GET/POST | 否 | 否 | Cookie 导入 UI |

---

## 源码结构

```
browse/src/
├── server.ts              [1700+行] HTTP 服务器核心
├── cli.ts                 [400+行]  CLI 包装、进程生命周期
├── browser-manager.ts     [900+行]  Chromium 管理、tab/ref
├── snapshot.ts            [464行]   ARIA 树、@ref、diff
├── commands.ts            [151行]   命令注册表（单一真相源）
├── read-commands.ts       [300+行]  内容提取
├── write-commands.ts      [900+行]  交互操作
├── meta-commands.ts       [600+行]  截图、tab、diff
├── buffers.ts             [138行]   环形缓冲区
├── activity.ts            [170+行]  Activity SSE 流
├── cdp-inspector.ts       [400+行]  CSS 检查器（CDP 协议）
├── config.ts              [151行]   状态路径解析
├── sidebar-agent.ts       [400+行]  Sidebar AI 代理
└── url-validation.ts      [100+行]  URL 安全验证
```

---

## 设计决策总结

| 决策 | 原因 |
|------|------|
| 守护进程（不是每次启动） | ~100ms/命令 vs ~3s/命令 |
| Bun HTTP server | 快、原生 TS、无 Node 依赖 |
| 单线程事件循环 | Tab 切换无需 mutex，无竞态 |
| 环形缓冲区 | 有界内存，无限日志流 |
| @ref 引用系统 | 比 CSS 选择器更稳定 |
| 状态文件原子写入 | 崩溃不损坏状态 |
| 30 分钟空闲关闭 | 资源回收，CLI 下次自动重启 |
| 不受信任内容标记 | 明确的信任边界 |
