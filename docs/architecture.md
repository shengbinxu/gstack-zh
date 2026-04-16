# gstack 架构解读

> 对应原文：[`ARCHITECTURE.md`](https://github.com/garrytan/gstack/blob/main/ARCHITECTURE.md)
> 本文在原文基础上加入中文注解和扩展说明。

---

## 核心架构思路

gstack 由两个完全独立的层构成：

```
┌──────────────────────────────────────────────────────┐
│  Layer 1: 技能层（Skills）                            │
│  • 35 个 Markdown 文件（SKILL.md）                   │
│  • Claude 读取并执行这些 prompt                       │
│  • 用模板系统（.tmpl）生成，不要手动编辑 SKILL.md    │
└──────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────┐
│  Layer 2: 浏览器层（Browse Daemon）                   │
│  • 编译为单一二进制的 Bun 应用                        │
│  • 长驻 Chromium 守护进程，持久化状态                 │
│  • Claude 通过工具调用与之交互                        │
└──────────────────────────────────────────────────────┘
```

**作者原话**：浏览器是难的部分，其他所有东西都是 Markdown。

---

## 浏览器层：守护进程模型

### 为什么不每次命令都启动浏览器？

| 方案 | 优点 | 缺点 |
|------|------|------|
| 每次命令冷启动 Chromium | 简单 | 每次 2-3s 启动时间；丢失 cookies/登录状态；20条命令 = 40+秒等待 |
| 长驻守护进程（gstack方案） | 首次启动后每次 ~100-200ms；状态持久化 | 需要进程管理 |

gstack 选择了守护进程，并通过自动化机制解决进程管理问题：
- **自动启动**：第一次调用时启动（~3秒）
- **自动关闭**：空闲30分钟后自动退出
- **零配置**：状态写入 `.gstack/browse.json`，CLI 自动读取

### 通信架构

```
Claude Code                        gstack browse 二进制
─────────                         ──────────────────────
                                  ┌──────────────────────┐
  $B snapshot -i                  │  CLI（编译二进制）    │
  ──────────────────────────────→ │  • 读 .gstack/browse.json │
                                  │  • POST /command      │
                                  │    to localhost:PORT  │
                                  └──────────┬───────────┘
                                             │ HTTP（localhost）
                                  ┌──────────▼───────────┐
                                  │  Server（Bun.serve）  │
                                  │  • 派发命令           │
                                  │  • 与 Chromium 通信   │
                                  │  • 返回纯文本         │
                                  └──────────┬───────────┘
                                             │ CDP协议
                                  ┌──────────▼───────────┐
                                  │  Chromium（无头）     │
                                  │  • 持久化标签页       │
                                  │  • Cookies 跨命令保留 │
                                  │  • 30分钟空闲超时     │
                                  └───────────────────────┘
```

**CDP**（Chrome DevTools Protocol）：Chrome 提供的原生调试/控制协议，Playwright 底层也用它。

### 状态文件（State File）

```json
// .gstack/browse.json
{
  "pid": 12345,           // 服务器进程ID
  "port": 34567,          // 随机端口（10000-60000）
  "token": "uuid-v4",     // 认证令牌，防止本地端口被其他程序调用
  "startedAt": "...",     // 启动时间
  "binaryVersion": "abc123"  // 二进制版本hash，用于检测更新
}
```

**随机端口**的设计原因：支持多个 Conductor 工作区同时运行各自独立的 browse 守护进程，互不干扰。旧方案扫描固定端口范围（9400-9409），在多工作区场景下频繁冲突。

### 版本自动重启

每次构建时，`git rev-parse HEAD` 被写入 `browse/dist/.version`。CLI 每次启动时检查运行中的服务器版本是否匹配：
- 匹配 → 直接复用
- 不匹配 → 杀掉旧服务器，启动新服务器

这彻底消灭了"重新编译后旧进程还在跑"这类 bug。

---

## 技术选型：为什么用 Bun？

| 特性 | 原因 |
|------|------|
| **编译为单一二进制** | `bun build --compile` 输出 ~58MB 可执行文件，无需 node_modules，安装到 `~/.claude/skills/` 后开箱即用 |
| **内置 SQLite** | 读取 Chromium 的 Cookie 数据库无需额外依赖（Node.js 需要 `better-sqlite3` + 原生编译） |
| **原生运行 TypeScript** | 开发时 `bun run server.ts` 直接运行，无需编译步骤 |
| **内置 HTTP 服务器** | `Bun.serve()` 简单快速，无需 Express/Fastify |

**瓶颈在 Chromium，不在运行时**。Bun vs Node.js 的启动速度差异（~1ms vs ~100ms）在这里不是选它的原因——真正的原因是编译二进制和内置 SQLite。

---

## 技能层：模板系统

> 详细解读见 [how-skills-work.md](./how-skills-work.md)



```
编辑这里 ↓           运行这个 ↓           输出这个 ↓
SKILL.md.tmpl  →  bun run gen:skill-docs  →  SKILL.md
```

**SKILL.md.tmpl** 是真正的源文件，包含：
- YAML frontmatter（元数据）
- Markdown 正文（发给 Claude 的 prompt）
- `{{VARIABLE}}` 占位符（编译时展开）

**SKILL.md** 是生成文件，发给 Claude 执行。**永远不要直接编辑 SKILL.md**。

### 项目目录结构（按功能分组）

```
gstack/
│
├── browse/              # 无头浏览器 CLI（Playwright + Bun）
│   ├── src/commands.ts  # 命令注册表（单一事实来源）
│   ├── src/snapshot.ts  # 快照标志元数据
│   └── dist/            # 编译二进制（永远不要提交！）
│
├── scripts/             # 构建工具
│   ├── gen-skill-docs.ts       # 模板 → SKILL.md 编译器
│   ├── resolvers/              # 12个模板变量的解析器（v0.17.0.0新增 {{UX_PRINCIPLES}}）
│   └── host-config.ts          # 多宿主配置（Claude/Codex/Kiro等）
│
├── hosts/               # 各 AI 宿主配置
│   ├── claude.ts        # Claude Code 主配置
│   ├── codex.ts         # OpenAI Codex CLI
│   └── ...
│
├── [skill-name]/        # 每个技能一个目录
│   ├── SKILL.md.tmpl    # 模板（编辑这个）
│   └── SKILL.md         # 生成文件（不要编辑）
│
├── test/                # 测试套件
│   ├── skill-validation.test.ts    # 第1层：静态验证（免费，<1s）
│   ├── skill-llm-eval.test.ts      # 第3层：LLM-as-judge（约$0.15/次）
│   └── skill-e2e-*.test.ts          # 第2层：端到端（约$3.85/次）
│
└── bin/                 # CLI 工具集
    ├── gstack-review-log    # 写评审日志
    ├── gstack-learnings-*   # 管理历史经验
    └── remote-slug          # 获取项目标识符
```

---

## 多宿主设计（Multi-Host）

gstack 支持在不同 AI 宿主上运行，同一套技能对不同宿主生成不同内容：

| 宿主 | 特点 |
|------|------|
| Claude Code（主要） | 完整功能，包含所有交互提示 |
| OpenAI Codex CLI | 简化版，用 `$GSTACK_BIN` 环境变量替代路径 |
| Kiro / OpenCode / Slate | 适配各自的工具调用格式 |

模板变量解析器（resolvers）通过 `ctx.host` 判断当前宿主，生成对应内容。

---

## 数据持久化路径

gstack 运行时产生的数据分两类：

```
~/.gstack/                    # 用户级配置和数据
├── config.yaml               # 用户偏好（技能前缀、遥测、proactive模式）
├── projects/{slug}/          # 按项目存储的数据
│   ├── *-design-*.md         # 设计文档
│   └── *-eng-review-test-plan-*.md  # 测试计划
├── sessions/                 # 会话追踪
├── analytics/                # 使用分析
├── reviews/
│   └── review-log.jsonl      # 评审结果日志（/ship 看板依赖此文件）
└── browse.json               # 浏览器守护进程状态

~/.claude/memory/             # Claude Code 记忆系统
└── ai-work-logs/             # AI 工作日志（见 CLAUDE.md）
```

**设计原则**：用户数据写入 `~/.gstack/`（用户配置目录），永远不写入项目目录（除非明确是项目文件）。
