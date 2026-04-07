# `/plan-devex-review` 技能逐段中英对照注解

> 对应源文件：[`plan-devex-review/SKILL.md`](https://github.com/garrytan/gstack/blob/main/plan-devex-review/SKILL.md)（1833 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: plan-devex-review
preamble-tier: 3
version: 2.0.0
description: |
  Interactive developer experience plan review. Explores developer personas,
  benchmarks against competitors, designs magical moments, and traces friction
  points before scoring. Three modes: DX EXPANSION (competitive advantage),
  DX POLISH (bulletproof every touchpoint), DX TRIAGE (critical gaps only).
  Use when asked to "DX review", "developer experience audit", "devex review",
  or "API design review".
  Proactively suggest when the user has a plan for developer-facing products
  (APIs, CLIs, SDKs, libraries, platforms, docs). (gstack)
benefits-from: [office-hours]
allowed-tools:
  - Read
  - Edit
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
  - WebSearch
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/plan-devex-review` 触发。
- **version: 2.0.0**: 这是第 2 版。相比 v1，v2 的核心变化是引入了 Step 0 的深度调查框架（七个子步骤 0A-0G），把"打分"推迟到证据收集完毕后——不再是边审边打分，而是先把证据全摸清楚，再精准打分。
- **description**: 交互式开发者体验方案审查。在打分之前探索开发者角色、竞品基准测试、设计魔法时刻、追踪摩擦点。三种模式：DX EXPANSION（竞争优势）、DX POLISH（完善每个触点）、DX TRIAGE（只解决关键缺口）。
- **benefits-from: [office-hours]**: 建议先运行 `/office-hours`。如果已有 office-hours 设计文档，会自动读取用户画像信息。
- **allowed-tools**: 有 **Edit**——用于修改方案文档。有 **WebSearch**——用于竞品 DX 基准研究。

### plan-devex-review vs devex-review：根本区别

```
/plan-devex-review              /devex-review
  实现 BEFORE                   实现 AFTER
  ───────────────                ─────────────
  方案文档审查                    上线产品审计
  交互式 Q&A（7步调查）           自动化测试（browse）
  估算 TTHW                     实测 TTHW
  设计 Magical Moment            验证是否实现
  修改方案文档                    输出 DX Scorecard
  "应该是多好"                    "实际上是多好"
  预防为主                        事后诊断
  ───────────────                ─────────────
  DX 问题在代码里 = 容易修         DX 问题上线后 = 重构成本高
```

> **为什么在实现前做 DX 审查？**
> API 设计一旦上线，改 breaking change 要么影响所有用户，要么永久保留技术债务。CLI 的 flag 命名一旦固化，就有人写了脚本依赖它。错误信息格式一旦发布，就有人在 Stack Overflow 上引用它。在方案阶段修改，成本是几分钟。上线后修改，成本是版本迁移 + 用户教育 + 兼容层维护。

---

## 核心创新：产品类型检测

> **原文**：
> ```
> ## Product Type Detection (run first, before any questions)
>
> Read README.md and the plan being reviewed. Classify the product type from these signals:
> - Mentions API endpoints, REST, GraphQL, gRPC, webhooks → API/Service
> - Mentions CLI commands, flags, arguments, terminal → CLI Tool
> - Mentions npm install, import, require, library, package → Library/SDK
> - Mentions deploy, hosting, infrastructure, provisioning → Platform
> - Mentions docs, guides, tutorials, examples → Documentation
> - Mentions SKILL.md, skill template, Claude Code, AI agent, MCP → Claude Code Skill
> ```

**中文**：plan-devex-review 在开始任何问题之前，先检测产品类型。

| 产品类型 | 检测信号 | DX 关注点 |
|---------|---------|---------|
| API/Service | REST、GraphQL、webhooks | auth、错误码、SDK 完整性 |
| CLI Tool | commands、flags、arguments | `--help` 质量、flag 设计、输出格式 |
| Library/SDK | npm install、import、package | TypeScript 类型、安装一步完成 |
| Platform | deploy、hosting、infrastructure | 非交互模式、CI/CD 集成 |
| Documentation | guides、tutorials | 搜索、代码示例、版本切换 |
| Claude Code Skill | SKILL.md、AI agent、MCP | 语音触发器、preamble tier、工具声明 |

**产品类型影响什么**：

1. **Persona 选项**（0A步）：YC 创始人 vs 平台工程师 vs 前端开发者——不同类型产品的典型用户不同
2. **竞品基准**（0C步）：API 的竞品是 Stripe，CLI 的竞品是 gh/git，Library 的竞品是 axios/moment
3. **魔法时刻**（0D步）：API 的魔法 = 第一次 API 响应，CLI 的魔法 = 第一次命令输出
4. **审查 Pass**：某些 pass 在特定类型下更重要（Claude Code Skill 有独立的 Appendix 检查清单）

---

## Step 0：DX 调查框架（核心设计）

> **原文**：
> ```
> ## Step 0: DX Investigation (before scoring)
>
> The core principle: gather evidence and force decisions BEFORE scoring, not during
> scoring. Steps 0A through 0G build the evidence base. Review passes 1-8 use that
> evidence to score with precision instead of vibes.
> ```

**中文**：核心原则：在打分之前收集证据、强制决策，而不是边打分边猜测。步骤 0A 到 0G 建立证据基础。审查 Pass 1-8 使用这些证据精准打分，而不是凭感觉。

**v2 的根本变化**：v1 是"边读边打分"，v2 是"先调查，再打分"。这个顺序的改变消除了打分的主观性——每个分数背后都有：具体的角色、竞品基准数据、实际路径追踪。

Step 0 的七个子步骤形成一个完整的前期调查体系：

```
Step 0 调查框架（7步）
═══════════════════════════════════════════════════
0A  开发者角色审问     → 确定"谁在用"
        │
0B  同理心叙事         → 用第一人称模拟用户的体验
        │
0C  竞品 DX 基准测试   → 确定"应该多快"
        │
0D  魔法时刻设计       → 确定"什么是 wow 时刻"
        │
0E  模式选择           → 确定"深度还是广度"
        │
0F  旅程摩擦点追踪     → 确定"哪里会卡住"
        │
0G  首次开发者角色扮演  → 模拟"新人的完整体验"
        │
        ▼
证据库完整 → Pass 1-8 精准打分
```

---

## Step 0A：开发者角色审问

> **原文**：
> ```
> ### 0A. Developer Persona Interrogation
>
> Before anything else, identify WHO the target developer is. Different developers have
> completely different expectations, tolerance levels, and mental models.
>
> Gather evidence first: Read README.md for "who is this for" language. Check
> package.json description/keywords. Check design doc for user mentions.
> ```

**中文**：在做任何事之前，先确定目标开发者是**谁**。不同的开发者有完全不同的期望、容忍度和心智模型。

**为什么角色调查要放在第一步？**
因为评分的标准完全依赖于受众。同一个"5 步安装流程"：
- 对 YC 创始人来说 = 太麻烦，3/10
- 对平台工程师来说 = 正常，7/10（他们习惯看文档、理解前提条件）

**各产品类型的典型 Persona 示例**：

| Persona | 容忍度 | 期望 | 危险行为 |
|---------|--------|------|---------|
| **YC 创始人（MVP 阶段）** | 30 分钟集成 | 不看文档就能从 README 复制代码 | 遇到两个错误就切换到竞品 |
| **Series C 平台工程师** | 可以看文档 | 安全性、SLA、CI 集成 | 如果没有安全审计文档，拒绝引入 |
| **前端开发者** | 有耐心 | TypeScript 类型、包体积、React 示例 | 无类型定义 = 直接 pass |
| **后端 API 集成开发者** | 中等 | cURL 示例、auth 流程、限流文档 | 不知道如何认证就放弃 |
| **OSS 贡献者** | 高耐心 | `git clone && make test`、CONTRIBUTING.md | 没有贡献指南 = 不贡献 |
| **学生** | 需要引导 | 清晰的错误信息、大量示例 | 一个不清楚的错误就求助或放弃 |
| **DevOps 工程师** | 专业级 | Terraform/Docker、非交互模式、环境变量 | 需要 GUI 操作 = 拒绝自动化 |

**Persona 卡片输出格式**：

```
TARGET DEVELOPER PERSONA（目标开发者角色）
==========================================
Who:       YC 创始人，独立开发者，快速验证 MVP
Context:   周六下午，需要在 4 小时内集成支付功能
Tolerance: 15 分钟内如果没有成功，考虑换 Paddle
Expects:   README 第一段就有可运行的代码
```

> **设计原理：为什么要强制"先调查，再问问题"？**
> 很多审查工具直接问"你的目标用户是谁？"，然后等用户告诉你。plan-devex-review 的做法不同：先自己读文档推断，然后给出具体的选项（"我认为是 YC 创始人，对吗？"），让用户确认或纠正。这样的交互效率更高，也能发现产品文档里的受众定位不清晰问题。

---

## Step 0B：同理心叙事（Empathy Narrative）

> **原文**：
> ```
> ### 0B. Empathy Narrative as Conversation Starter
>
> Write a 150-250 word first-person narrative from the persona's perspective. Walk
> through the ACTUAL getting-started path from the README/docs. Be specific about
> what they see, what they try, what they feel, and where they get confused.
>
> Use the persona from 0A. Reference real files and content from the pre-review audit.
> Not hypothetical. Trace the actual path: "I open the README. The first heading is
> [actual heading]..."
> ```

**中文**：从角色视角写 150-250 词的第一人称叙事。走过 README/文档中**实际的** getting started 路径。具体描述他们看到什么、尝试什么、感受什么、在哪里困惑。

这一步有两个关键约束：
1. **不是假设**：必须引用真实文件内容和真实 README 标题
2. **第一人称**：不是"开发者会..."，而是"我打开 README，第一个标题是..."

**同理心叙事模板（示例）**：

```
我是一个 YC 创始人，周六下午开始集成 [产品名]。

我打开 README。第一个标题是 "Getting Started with [产品名]"。好的。
第一个代码块是 `npm install @company/sdk`。我运行它，30 秒后完成。
然后我看到 README 说 "Initialize the client with your API key"。
我去哪里获取 API key？README 里没说。我去 Dashboard 找...

[注：这是模板，实际内容必须来自真实文档]

T+2:00: 终于在 Settings → API → Keys 找到了 key。
T+3:00: 我复制了 README 里的示例代码。运行，报错：
         "Error: Invalid API endpoint format"
T+4:00: 我去搜索这个错误。Stack Overflow 没有结果。
         文档没有错误参考。我开始考虑切换到 [竞品]。
```

**这一步的输出用途**：同理心叙事成为方案 DX 部分的必要输出章节（"Developer Perspective"）。实现者读到它应该能**感受**到用户的困惑，不只是知道"有问题"。

---

## Step 0C：竞品 DX 基准测试

> **原文**：
> ```
> ### 0C. Competitive DX Benchmarking
>
> Before scoring anything, understand how comparable tools handle DX. Use WebSearch to
> find real TTHW data and onboarding approaches.
>
> Run three searches:
> 1. "[product category] getting started developer experience {current year}"
> 2. "[closest competitor] developer onboarding time"
> 3. "[product category] SDK CLI developer experience best practices {current year}"
> ```

**中文**：在打任何分之前，先了解同类工具是如何处理 DX 的。使用 WebSearch 找真实的 TTHW 数据和入门方式。

**竞品基准表格**：

```
COMPETITIVE DX BENCHMARK（竞品 DX 基准）
==========================================
Tool           | TTHW      | Notable DX Choice        | Source
Stripe         | 30s       | API key 预填到文档代码里  | [url]
Vercel         | 2min      | `vercel` 一行命令部署     | [url]
Firebase       | 3min      | 3 行代码实时同步          | [url]
YOUR PRODUCT   | 8min(est) | 来自当前 README          | 当前方案
```

然后 AskUserQuestion：

```
你的竞品 TTHW：
  Stripe: 30秒
  Vercel: 2分钟
  Firebase: 3分钟

你的方案当前估算：8分钟（5步）

你想达到哪个层级？

A) 冠军级（< 2分钟）—— 需要 [具体改动]。Stripe/Vercel 领域。
B) 竞争级（2-5分钟）—— 通过 [具体缺口] 可达
C) 当前轨迹（8分钟）—— 现在可接受，以后改进
D) 告诉我我们的实际限制
```

> **设计原理：为什么要用 WebSearch 而不是内置知识？**
> DX 领域进化很快——Stripe 今年的入门流程可能和去年不同。固化的知识库会过时。WebSearch 确保竞品基准是当前准确的数据，而不是 AI 模型训练时的旧数据。如果 WebSearch 不可用，使用内置参考基准，但要明确声明数据来源和局限性。

---

## Step 0D：魔法时刻设计

> **原文**：
> ```
> ### 0D. Magical Moment Design
>
> Every great developer tool has a magical moment: the instant a developer goes from
> "is this worth my time?" to "oh wow, this is real."
>
> Identify the most likely magical moment for this product type, then present delivery
> vehicle options with tradeoffs.
> ```

**中文**：每个优秀的开发者工具都有一个魔法时刻：开发者从"这值得我的时间吗？"转变为"哦哇，这是真实的！"的那个瞬间。

**不同产品类型的魔法时刻**：

| 产品类型 | 魔法时刻 | 标志性案例 |
|---------|---------|-----------|
| Payment API | 第一笔成功的 API 响应（看到真实的金额移动） | Stripe Dashboard 的第一笔测试交易 |
| Deploy Platform | 看到自己的代码上线（URL 出现） | Vercel 的 `git push` → 60 秒后有 URL |
| Auth Service | 第一次成功的登录/注册流程工作 | Clerk 的三行 JSX 完成整套 Auth |
| Database | 第一次查询返回真实数据 | Supabase 自动生成 API 的那一刻 |
| CLI Tool | 第一次命令产生有意义的输出 | `gh pr create` 然后看到 PR 链接 |

**四种交付载体（Delivery Vehicle）**：

```
A) Interactive Playground（交互式 Playground）
   └── 零安装，在浏览器中尝试
   └── 最高转化率，但需要构建托管环境
   └── 人工: ~1周 / CC: ~2小时
   └── 案例: Stripe API Explorer, Supabase SQL Editor

B) Copy-paste demo command（一条命令）
   └── 一个终端命令产生魔法输出
   └── 对 CLI 工具效果最好，但需要先本地安装
   └── 人工: ~2天 / CC: ~30分钟
   └── 案例: npx create-next-app, docker run hello-world

C) Video/GIF walkthrough（视频/GIF 演示）
   └── 展示魔法而不需要任何设置
   └── 被动（开发者只是观看），零摩擦
   └── 人工: ~1天 / CC: ~1小时
   └── 案例: Vercel 首页的部署动画

D) Guided tutorial with user's own data（引导教程）
   └── 用开发者自己的项目逐步引导
   └── 最深的参与，但到达魔法时刻的时间最长
   └── 人工: ~1周 / CC: ~2小时
   └── 案例: Stripe 的交互式入门流程
```

> **设计原理：为什么要主动设计魔法时刻？**
> 大多数产品的 getting started 是"功能性的"——开发者能工作，但没有 wow 时刻。魔法时刻的设计是主动的，不是自然发生的。Stripe 为什么要把 API key 预填到文档里？因为有人主动问："如何让第一次 API 调用感觉更流畅？"这个问题就是 plan-devex-review 要强迫提出的问题。

---

## Step 0E：模式选择（三种模式）

> **原文**：
> ```
> ### 0E. Mode Selection
>
> A) DX EXPANSION -- Your developer experience could be a competitive advantage.
>    I'll propose ambitious DX improvements beyond what the plan covers.
>
> B) DX POLISH -- The plan's DX scope is right. I'll make every touchpoint bulletproof:
>    error messages, docs, CLI help, getting started. No scope additions, maximum rigor.
>    (recommended for most reviews)
>
> C) DX TRIAGE -- Focus only on the critical DX gaps that would block adoption.
>    Fast, surgical, for plans that need to ship soon.
>
> Context-dependent defaults:
> * New developer-facing product → default DX EXPANSION
> * Enhancement to existing product → default DX POLISH
> * Bug fix or urgent ship → default DX TRIAGE
> ```

**三种模式对比**：

```
             │ DX EXPANSION      │ DX POLISH          │ DX TRIAGE
─────────────┼───────────────────┼────────────────────┼──────────────────
定位         │ 竞争优势           │ 精益求精           │ 快速修复关键缺口
范围         │ 扩展（opt-in）     │ 保持               │ 仅关键问题
姿态         │ 充满热情           │ 严格               │ 外科手术式
竞品分析     │ 完整基准           │ 完整基准           │ 跳过
魔法时刻     │ 完整设计           │ 验证存在           │ 跳过
旅程追踪     │ 所有阶段 + 最佳实践│ 所有阶段           │ 仅安装 + Hello World
审查 Pass    │ 全部 8 个，扩展    │ 全部 8 个，标准    │ Pass 1 + Pass 3 only
独立声音     │ 推荐               │ 推荐               │ 跳过
─────────────┴───────────────────┴────────────────────┴──────────────────
适用场景     │ 新开发者产品        │ 增强现有产品        │ 紧急发布修复
```

> **设计原理：为什么需要三种模式？**
> DX EXPANSION 给正在打造差异化产品的团队——让 DX 成为竞争武器。DX POLISH 给成熟产品——不扩展范围，但让每个触点都无懈可击。DX TRIAGE 给时间紧迫的团队——快速找到会阻断采用的关键问题。没有"一种模式适合所有情况"，因为不同阶段的团队有完全不同的约束条件。

---

## Step 0F：开发者旅程摩擦点追踪

> **原文**：
> ```
> ### 0F. Developer Journey Trace with Friction-Point Questions
>
> For each journey stage, TRACE the actual experience (what file, what command, what
> output) and ask about each friction point individually.
>
> For each stage (Discover, Install, Hello World, Real Usage, Debug, Upgrade):
> 1. Trace the actual path. Read the README, docs, package.json, CLI help...
>    Reference specific files and line numbers.
> 2. Identify friction points with evidence. Not "installation might be hard" but
>    "Step 3 of the README requires Docker to be running, but nothing checks for
>    Docker or tells the developer to install it."
> 3. AskUserQuestion per friction point. One question per friction point found.
>    Do NOT batch multiple friction points into one question.
> ```

**开发者旅程的六个阶段**：

```
发现 → 安装 → Hello World → 真实使用 → 调试 → 升级
  ↑      ↑        ↑           ↑          ↑      ↑
每个阶段都必须追踪实际路径，不是假设路径
```

**旅程追踪的精髓是"有证据的摩擦点"**：

| 模糊描述（不可接受） | 有证据的描述（正确做法） |
|-------------------|---------------------|
| "安装可能很困难" | "README 第 3 步要求 Docker 运行，但没有检查 Docker 是否存在，也没有提示如何安装。没有 Docker 的 YC 创始人会看到一个神秘的 `connection refused` 错误。" |
| "错误信息不够清晰" | "运行 `sdk.init()` 时，如果没有 API key，返回 `TypeError: Cannot read property 'key' of undefined`，没有任何指引说如何获取 API key。" |
| "文档难以找到" | "文档导航有 47 个条目，没有搜索功能，'Getting Started' 在第 15 个条目，不在首位。" |

**旅程地图输出格式**：

```
STAGE           | DEVELOPER DOES              | FRICTION POINTS      | STATUS
────────────────┼─────────────────────────────┼──────────────────────┼────────────
1. 发现         | 搜索 "product name"          | [已解决/已推迟]      | [fixed/ok/deferred]
2. 安装         | npm install @co/sdk          | Docker 未声明        | deferred
3. Hello World  | sdk.init(); await sdk.call() | 缺少 API key 提示    | fixed
4. 真实使用     | 添加 error handling          | 无错误类型定义        | fixed
5. 调试         | 解读错误信息                  | 错误码无文档          | deferred
6. 升级         | 读 CHANGELOG                  | 无迁移指南            | fixed
```

---

## Step 0G：首次开发者角色扮演

> **原文**：
> ```
> ### 0G. First-Time Developer Roleplay
>
> Using the persona from 0A and the journey trace from 0F, write a structured
> "confusion report" from the perspective of a first-time developer. Include
> timestamps to simulate real time passing.
>
> CONFUSION LOG:
> T+0:00  [What they do first. What they see.]
> T+0:30  [Next action. What surprised or confused them.]
> ...
> T+3:00  [Final state: gave up / succeeded / asked for help]
> ```

**"困惑报告"模板**：

```
FIRST-TIME DEVELOPER REPORT（首次开发者报告）
============================================
Persona: YC 创始人，集成支付功能
Attempting: [产品名] getting started

CONFUSION LOG：
T+0:00  打开 README。看到 npm install 命令。运行它。成功。
T+0:45  看到 "Initialize client with API key"。去哪找 key？README 没说。
T+1:30  在 Dashboard 的 Settings → API 里找到了 key。回来继续。
T+2:15  运行示例代码。报错：
          "Error: Invalid endpoint. Expected 'v2', got 'v1'."
          没有说明应该用哪个版本的 endpoint。
T+3:30  在 GitHub Issues 搜到了答案（9 个月前的 issue）。
T+4:00  成功运行 hello world，但感觉像在打怪，不像在用工具。
FINAL: 成功了，但不会告诉团队成员"很容易用"。
```

这个报告的价值是**时间戳**——它把抽象的"摩擦"变成了具体的时间损失。"4 分钟才成功"是可以量化的，"体验不好"是不可以量化的。

---

## 第三部分：0-10 评分方法

> **原文**：
> ```
> ## The 0-10 Rating Method
>
> Critical rule: Every rating MUST reference evidence from Step 0. Not "Getting
> Started: 4/10" but "Getting Started: 4/10 because [persona from 0A] hits [friction
> point from 0F] at step 3, and competitor [name from 0C] achieves this in [time]."
>
> Pattern:
> 1. Evidence recall: Reference specific findings from Step 0
> 2. Rate: "Getting Started Experience: 4/10"
> 3. Gap: "It's a 4 because [evidence]. A 10 would be [specific description for THIS product]."
> 4. Load Hall of Fame reference
> 5. Fix: Edit the plan
> 6. Re-rate
> 7. AskUserQuestion if genuine DX choice
> 8. Fix again until 10 or user says "good enough"
> ```

**评分的七步循环**（每个 Pass 都要走这个循环）：

```
┌─────────────────────────────────────────────────────┐
│             Pass N 评分循环                          │
└─────────────────────────────────────────────────────┘
        │
   1. 证据召回
   ├── 哪个 persona（0A）
   ├── 哪个竞品基准（0C）
   ├── 哪个魔法时刻（0D）
   └── 哪些摩擦点（0F/0G）
        │
   2. 打出初始分数（附证据）
   "Getting Started: 4/10，因为 [persona] 在步骤3遇到 [摩擦点]，
    而竞品 Stripe 在 30 秒内完成同等任务"
        │
   3. Gap 分析
   "是 4 因为 [证据]。10 分对这个产品意味着 [具体描述]"
        │
   4. 读 Hall of Fame 该 Pass 的参考（只读当前 Pass 对应章节）
        │
   5. 修改方案（Edit 工具）
        │
   6. 重新打分
        │
   7. 如果有真正的 DX 选择 → AskUserQuestion
   8. 继续修改直到 10 分 或 用户说"够好了"
```

**模式特定行为**：
- **DX EXPANSION**：到 10 分后，还要问"什么能让这个维度成为最佳实践？"，提出扩展建议
- **DX POLISH**：修复每个缺口，不走捷径，追踪到具体文件/行号
- **DX TRIAGE**：只标记分数低于 5 的问题（会阻断采用的），跳过 5-7 分的改进建议

---

## 第四部分：八个审查 Pass

> **原文（anti-skip rule）**：
> ```
> Anti-skip rule: Never condense, abbreviate, or skip any review pass (1-8)
> regardless of plan type. Every pass in this skill exists for a reason.
> "This is a strategy doc so DX passes don't apply" is always wrong — DX gaps
> are where adoption breaks down. If a pass genuinely has zero findings, say
> "No issues found" and move on — but you must evaluate it.
> ```

**中文**：反跳过规则：无论方案类型如何，永远不要简化、缩减或跳过任何审查 pass（1-8）。"这是一个策略文档，所以 DX pass 不适用"永远是错的——DX 缺口是采用中断的地方。如果一个 pass 真的没有发现，说"未发现问题"然后继续——但你必须评估它。

### Pass 1：Getting Started 体验（零摩擦）

> **原文**：
> ```
> Rate 0-10: Can a developer go from zero to hello world in under 5 minutes?
>
> Evaluate:
> - Installation: One command? One click? No prerequisites?
> - First run: Does the first command produce visible, meaningful output?
> - Sandbox/Playground: Can developers try before installing?
> - Free tier: No credit card, no sales call, no company email?
> - Auth/credential bootstrapping: Steps between "I want to try" and "it works"?
> - Magical moment delivery: Is the vehicle chosen in 0D actually in the plan?
> - Competitive gap: How far is the TTHW from the target tier chosen in 0C?
>
> Stripe test: Can a [persona] go from "never heard of this" to "it worked"
> in one terminal session without leaving the terminal?
> ```

**Stripe 测试**是最简单的黄金标准：开发者能否在不离开终端的情况下，从"从没听说过"到"它工作了"？

**典型 Anti-patterns**（来自 Hall of Fame）：

| Anti-pattern | 影响 |
|-------------|------|
| API key 隐藏在 Settings 深处 | T+2:00 开发者迷路找 key |
| 要求邮件验证才能看到任何值 | 流程中断，等待邮件 |
| 信用卡才能进沙盒 | 50% 的评估者离开 |
| 多条路径（"选择你的框架..."） | 决策疲劳，选择无效 |
| 静态代码示例（无语言切换） | 非 JS 开发者无法直接用 |

### Pass 2：API/CLI/SDK 设计（可用+有用）

> **原文**：
> ```
> Evaluate:
> - Naming: Guessable without docs? Consistent grammar?
> - Defaults: Every parameter has a sensible default?
> - Consistency: Same patterns across the entire API surface?
> - Completeness: 100% coverage or do devs drop to raw HTTP for edge cases?
> - Discoverability: Can devs explore from CLI/playground without docs?
> - Progressive disclosure: Simple case is production-ready?
> - Persona fit: Does the interface match how [persona] thinks about the problem?
>
> Good API design test: Can a [persona] use this API correctly after seeing one example?
> ```

**API 设计金标准**（来自 Hall of Fame）：

```
Stripe 预填充 ID：
  ch_ 代表 charge，cus_ 代表 customer
  → 自文档化，不可能传错类型的 ID

Stripe 可展开对象：
  默认返回 ID 字符串，expand[] 获取完整对象
  → 渐进式披露的完美实现

Stripe 幂等键：
  传 Idempotency-Key header = 安全重试
  → 消除"我是否重复收费了？"的焦虑

GitHub CLI 自动检测输出：
  终端 = 人类可读；管道 = 制表符分隔
  → 同一命令，两种受众
```

**API 设计 Anti-patterns**：

| 模式名 | 描述 | 后果 |
|-------|------|------|
| 聊天式 API | 一个用户操作需要 5 次 API 调用 | 复杂、慢、容易部分成功 |
| 命名不一致 | `/users`（复数）vs `/user/123`（单数）vs `/create-order`（动词） | 开发者必须记忆每个端点的命名风格 |
| 隐式失败 | 200 OK 但错误嵌套在响应体里 | 需要每次解析 body 才知道是否成功 |
| 上帝端点 | 47 种参数组合，每种子集行为不同 | 无法测试，无法文档化 |
| 需要文档的 API | 3 页文档才能发出第一个请求 | 开发者逃逸 |

### Pass 3：错误信息与调试（对抗不确定性）

> **原文**：
> ```
> Trace 3 specific error paths from the plan or codebase. For each, evaluate
> against the three-tier system:
> - Tier 1 (Elm): Conversational, first person, exact location, suggested fix
> - Tier 2 (Rust): Error code links to tutorial, primary + secondary labels
> - Tier 3 (Stripe API): Structured JSON with type, code, message, param, doc_url
> ```

**错误信息评分矩阵**：

```
                    包含以下要素的个数
     ┌──────────────────────────────────────┐
  10 │ 发生了什么 + 为什么 + 如何修复 + 文档链接 + 实际值 │
   8 │ 发生了什么 + 为什么 + 如何修复 + 文档链接         │
   6 │ 发生了什么 + 为什么 + 如何修复                   │
   4 │ 发生了什么 + 为什么                              │
   2 │ 发生了什么（但不够清晰）                          │
   0 │ 堆栈跟踪 + 内部变量名，无用户可理解信息             │
     └──────────────────────────────────────┘
```

**Pass 3 的独特评估项**：
- **权限/沙箱/安全模型**：什么可能出错？爆炸半径有多清晰？
- **调试模式**：是否有详细输出选项？
- **堆栈跟踪**：有用还是内部框架噪音？

### Pass 4：文档与学习（可发现+动手学习）

**信息架构测试**：开发者能否在 2 分钟内找到他们需要的内容？

```
Stripe 文档三栏设计（黄金标准）：
  左栏：导航
  中栏：内容
  右栏：可运行的代码（语言切换 + API key 预填）
  → 开发者永远不需要离开文档页面
```

**Pass 4 的关键检查项**：

| 项目 | 检查方式 | 金标准 |
|------|---------|--------|
| 信息架构 | 计时：找到特定内容需要多久 | < 2 分钟 |
| 代码示例 | 是否可以直接复制粘贴运行 | 零配置运行 |
| 版本同步 | 文档是否匹配开发者使用的版本 | 版本选择器 |
| 教程 vs 参考 | 两者是否都存在 | 各自完整 |
| 搜索 | 搜索 3 个常见查询的质量 | 第一结果命中 |

### Pass 5：升级与迁移路径（可信）

> **原文**：
> ```
> Evaluate:
> - Backward compatibility: What breaks? Blast radius limited?
> - Deprecation warnings: Advance notice? Actionable? ("use newMethod() instead")
> - Migration guides: Step-by-step for every breaking change?
> - Codemods: Automated migration scripts?
> - Versioning strategy: Semantic versioning? Clear policy?
> ```

**升级恐惧的根源**：每次升级，开发者都在问：
- "这会破坏我的生产环境吗？"
- "需要多少工作量来升级？"
- "迁移指南是否完整？"

**缓解升级恐惧的工具链**：

```
语义化版本 + 废弃警告 + 迁移指南 + Codemods = 无聊的升级

每个组件的作用：
  语义化版本：MAJOR.MINOR.PATCH 明确区分 breaking change
  废弃警告：提前告知 "此方法将在 v4.0 移除，请使用 newMethod()"
  迁移指南：逐步说明从 vX 到 vY 的每个变化
  Codemods：自动化迁移脚本，让升级变成一条命令
```

### Pass 6：开发者环境与工具（有价值+可及）

> **原文**：
> ```
> Evaluate:
> - Editor integration: Language server? Autocomplete? Inline docs?
> - CI/CD: Works in GitHub Actions, GitLab CI? Non-interactive mode?
> - TypeScript support: Types included? Good IntelliSense?
> - Testing support: Easy to mock? Test utilities?
> - Local development: Hot reload? Watch mode? Fast feedback?
> - Cross-platform: Mac, Linux, Windows? Docker? ARM/x86?
> - Local env reproducibility: Works across OS, package managers, containers, proxies?
> ```

**Pass 6 的关键洞察**：开发者工具活在开发者的工作流里。如果工具在 CI/CD 环境中需要特殊配置，就会在团队推广时遇到阻力。如果没有 TypeScript 类型，前端开发者不会在 TypeScript 项目中引入它。

### Pass 7：社区与生态（可发现+令人向往）

```
社区投资的阶梯：

Desirable（令人向往）
  ↑ 开发者主动推荐，建立 Twitter/YouTube 内容生态
Findable（可发现）
  ↑ Stack Overflow 有答案，Discord 活跃
Accessible（可及）
  ↑ 有 CONTRIBUTING.md，issue 模板，PR 流程清晰
Useful（有用）
  ↑ 有真实世界的示例，不只是 hello world
```

### Pass 8：DX 度量与反馈循环

> **原文**：
> ```
> Evaluate:
> - TTHW tracking: Can you measure getting started time? Is it instrumented?
> - Journey analytics: Where do devs drop off?
> - Feedback mechanisms: Bug reports? NPS? Feedback button?
> - Friction audits: Periodic reviews planned?
> - Boomerang readiness: Will /devex-review be able to measure reality vs. plan?
> ```

**Pass 8 的独特关注点——"回旋镖就绪性"**：

方案是否为后续的 `/devex-review` 留出了可测量的接口？如果没有任何分析或度量，`/devex-review` 只能靠截图估算，无法量化改进。Pass 8 是在为"闭环"做准备。

```
DX 改进闭环：

/plan-devex-review
  → 设计 DX（估算 TTHW: 3 min）
       │
       ▼ [实现]
       │
/devex-review
  → 测量现实（实测 TTHW: 8 min）
       │ 
       ▼ Pass 8 发现缺少度量
       │
修复：加入 TTHW 埋点
       │
       ▼ [再次测量]
       │
/devex-review
  → 实测 TTHW: 2.5 min ✓
```

---

## 第五部分：必要输出（Required Outputs）

plan-devex-review 的输出不只是"评分"——它是一套完整的方案增强文档。

> **原文**：
> ```
> Required Outputs:
> - Developer Persona Card (from 0A)
> - Developer Empathy Narrative (from 0B, updated with corrections)
> - Competitive DX Benchmark (from 0C, updated with post-review scores)
> - Magical Moment Specification (from 0D with implementation requirements)
> - Developer Journey Map (from 0F with friction point resolutions)
> - First-Time Developer Confusion Report (from 0G with addressed items)
> - "NOT in scope" section
> - "What already exists" section
> - TODOS.md updates
> - DX Scorecard
> - DX Implementation Checklist
> - Unresolved Decisions
> ```

### DX Scorecard（含趋势追踪）

> **原文**：
> ```
> +====================================================================+
> |              DX PLAN REVIEW — SCORECARD                             |
> +====================================================================+
> | Dimension            | Score  | Prior  | Trend  |
> |----------------------|--------|--------|--------|
> | Getting Started      | __/10  | __/10  | __ ↑↓  |
> | API/CLI/SDK          | __/10  | __/10  | __ ↑↓  |
> | Error Messages       | __/10  | __/10  | __ ↑↓  |
> | Documentation        | __/10  | __/10  | __ ↑↓  |
> | Upgrade Path         | __/10  | __/10  | __ ↑↓  |
> | Dev Environment      | __/10  | __/10  | __ ↑↓  |
> | Community            | __/10  | __/10  | __ ↑↓  |
> | DX Measurement       | __/10  | __/10  | __ ↑↓  |
> +--------------------------------------------------------------------+
> | TTHW                 | __ min | __ min | __ ↑↓  |
> | Competitive Rank     | [Champion/Competitive/Needs Work/Red Flag]   |
> | Magical Moment       | [designed/missing] via [delivery vehicle]    |
> | Product Type         | [type]                                      |
> | Mode                 | [EXPANSION/POLISH/TRIAGE]                    |
> | Overall DX           | __/10  | __/10  | __ ↑↓  |
> +====================================================================+
> ```

**设计亮点**：Scorecard 有 **Prior** 和 **Trend** 列——追踪历史变化。这让每次 DX 审查都能看到进步还是退步，不再是每次都从零开始评估。

### DX Implementation Checklist（实现检查清单）

> **原文**：
> ```
> DX IMPLEMENTATION CHECKLIST
> ============================
> [ ] Time to hello world < [target from 0C]
> [ ] Installation is one command
> [ ] First run produces meaningful output
> [ ] Magical moment delivered via [vehicle from 0D]
> [ ] Every error message has: problem + cause + fix + docs link
> [ ] API/CLI naming is guessable without docs
> [ ] Every parameter has a sensible default
> [ ] Docs have copy-paste examples that actually work
> [ ] Examples show real use cases, not just hello world
> [ ] Upgrade path documented with migration guide
> [ ] Breaking changes have deprecation warnings + codemods
> [ ] TypeScript types included (if applicable)
> [ ] Works in CI/CD without special configuration
> [ ] Free tier available, no credit card required
> [ ] Changelog exists and is maintained
> [ ] Search works in documentation
> [ ] Community channel exists and is monitored
> ```

这个检查清单是**方案 DX 审查的最终输出**。不管审查过程有多复杂，最后都落到这 17 个可操作的勾选项上。开发者拿到这个清单，就知道实现时要做什么。

---

## 第六部分：DX 第一性原理（与 devex-review 相同）

plan-devex-review 继承了与 devex-review 相同的 8 条 DX 第一性原理和 7 个 DX 特征框架（详见 devex-review.md 的第一和第二部分）。在方案阶段使用这些原理的方式是：

1. **每条建议必须追溯到具体原理**：不说"Getting Started 不够好"，说"这违反了原则 1（T0 零摩擦），因为第 3 步要求信用卡，Stripe 在同等操作中不要求。"
2. **DX Principle Coverage 部分**：Scorecard 底部有一个原理覆盖检查，确保 8 条原理都被考虑。
3. **Hall of Fame 按 Pass 分章节加载**：每个 Pass 只加载对应章节，保持上下文聚焦。

---

## 第七部分：独立声音（Outside Voice）

> **原文**：
> ```
> After all review sections are complete, offer an independent second opinion from a
> different AI system. Two models agreeing on a plan is stronger signal than one
> model's thorough review.
>
> Construct the plan review prompt... include the Developer Persona from Step 0A
> and the Competitive Benchmark from Step 0C. The outside voice should critique
> the plan in the context of who is using it and what they're competing against.
> ```

**独立声音机制**（plan-devex-review 的独特设计）：

所有审查 pass 完成后，可以向独立 AI 系统（Codex 或 Claude 子代理）发出挑战请求。两个模型同意一个方案，比一个模型的彻底审查有更强的信号。

关键约束：
- **用户主权（User Sovereignty）**：独立声音的建议不能自动合并到方案中。每个分歧点都要通过 AskUserQuestion 征得用户同意。
- **跨模型张力（Cross-model Tension）**：当独立声音与内部审查意见分歧时，明确呈现两种观点，不做预设。

```
CROSS-MODEL TENSION（跨模型张力示例）：
  [API 设计]: 审查说"使用 REST"。独立声音说"应该是 GraphQL，
              因为 [persona] 需要灵活的查询"。
              [呈现两种观点，让用户决定。]
```

---

## 第八部分：TODOS.md 集成

> **原文**：
> ```
> ### TODOS.md updates
>
> After all review passes are complete, present each potential TODO as its own
> individual AskUserQuestion. Never batch. For DX debt: missing error messages,
> unspecified upgrade paths, documentation gaps, missing SDK languages. Each TODO gets:
> * What: One-line description
> * Why: The concrete developer pain it causes
> * Pros/Cons/Context/Depends
> Options: A) Add to TODOS.md  B) Skip  C) Build it now
> ```

TODOS.md 集成的设计理念：DX 债务是真实的债务。每个"稍后解决"的 DX 问题都有具体的开发者痛苦代价。通过把每个潜在 TODO 单独呈现（而不是批量），确保用户对每个决定都是有意识的，而不是无意识地堆积债务。

---

## 第九部分：Review Log 与趋势追踪

```bash
~/.claude/skills/gstack/bin/gstack-review-log '{
  "skill":"plan-devex-review",
  "timestamp":"...",
  "status":"...",
  "initial_score":N,
  "overall_score":N,
  "product_type":"...",
  "tthw_current":"...",
  "tthw_target":"...",
  "mode":"EXPANSION/POLISH/TRIAGE",
  "persona":"yc-founder",
  "competitive_tier":"Champion/Competitive/NeedsWork/RedFlag",
  "pass_scores":{...},
  "unresolved":N,
  "commit":"..."
}'
```

这些字段在 `/devex-review` 的回旋镖对比中会被读取，形成完整的"方案承诺 vs 现实"数据链。

---

## 第十部分：与整个 gstack 审查体系的关系

```
完整的方案审查体系：

/autoplan ──────────────────────────────────────┐
    │                                            │
    ├── /plan-ceo-review     范围与战略           │
    │         │                                   │
    ├── /plan-eng-review     架构与测试（必须）    │
    │         │                                   │
    ├── /plan-design-review  UI/UX（可选）        ├── GSTACK REVIEW REPORT
    │         │                                   │
    ├── /plan-devex-review   开发者体验（可选）    │
    │         │                                   │
    └── /codex review        独立第二意见          │
              │                                   │
              ▼                                   │
        VERDICT: CLEARED ───────────────────────┘
              │
              ▼
        [实现代码]
              │
              ▼
        /devex-review（回旋镖：现实 vs 承诺）
```

plan-devex-review 是唯一专注于**开发者用户（Developer as User）**的审查技能。其他审查关注的是：
- plan-eng-review：代码的工程师（内部关注点）
- plan-design-review：最终用户的体验
- plan-ceo-review：产品策略
- plan-devex-review：**使用这个产品的开发者的体验**

---

## 第十一部分：问题规则（CRITICAL RULE）

> **原文**：
> ```
> ## CRITICAL RULE — How to ask questions
>
> * One issue = one AskUserQuestion call. Never combine multiple issues.
> * Ground every question in evidence. Reference the persona, competitive benchmark,
>   empathy narrative, or friction trace. Never ask in the abstract.
> * Frame pain from the persona's perspective. Not "developers would be frustrated"
>   but "[persona from 0A] would hit this at minute [N] of their getting-started flow
>   and [specific consequence: abandon, file an issue, hack a workaround]."
> * Map to DX First Principles above. One sentence connecting your recommendation
>   to a specific principle.
> * Escape hatch: If a section has no issues, say so and move on.
> ```

**五条提问规则的设计理由**：

| 规则 | 为什么重要 |
|------|----------|
| 一个问题 = 一次 AskUserQuestion | 多个问题在一次调用中 = 用户会只回答第一个，其余被忽略 |
| 基于证据的问题 | 抽象问题 → 抽象回答；具体问题 → 可操作的回答 |
| 从角色视角描述痛苦 | "开发者会沮丧"无法量化；"YC 创始人会在第4分钟放弃"可以行动 |
| 连接到 DX 原理 | 让每个建议有理论依据，而不只是个人偏好 |
| 逃生通道 | 如果一个 pass 没有问题，不要强迫找问题——说"没发现问题"然后继续 |

---

## 总结：plan-devex-review 的核心价值

1. **预防为主**：方案阶段修改比上线后修改成本低 10-100 倍
2. **角色驱动**：所有评分都基于具体开发者角色，不是抽象的"开发者"
3. **竞品校准**：用 Stripe/Vercel 等金标准校准评分，避免"感觉不错但没到标准"
4. **魔法时刻设计**：主动设计而非被动发现
5. **回旋镖准备**：方案阶段的估算分数，为后续 /devex-review 的对比奠定基础
6. **三种模式**：根据产品阶段和时间压力选择不同深度

> **一句话定位**：plan-devex-review 是面向开发者产品的"实现前 DX 防御性审查"，用七步调查（角色→竞品→魔法→模式→旅程→角色扮演→打分）把 DX 问题在代码写下去之前就消灭掉，并为后续的实测（/devex-review）设定可对比的基准。
