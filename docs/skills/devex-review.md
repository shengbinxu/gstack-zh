# `/devex-review` 技能逐段中英对照注解

> 对应源文件：[`devex-review/SKILL.md`](https://github.com/garrytan/gstack/blob/main/devex-review/SKILL.md)（1034 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: devex-review
preamble-tier: 3
version: 1.0.0
description: |
  Live developer experience audit. Uses the browse tool to actually TEST the
  developer experience: navigates docs, tries the getting started flow, times
  TTHW, screenshots error messages, evaluates CLI help text. Produces a DX
  scorecard with evidence. Compares against /plan-devex-review scores if they
  exist (the boomerang: plan said 3 minutes, reality says 8). Use when asked to
  "test the DX", "DX audit", "developer experience test", or "try the
  onboarding". Proactively suggest after shipping a developer-facing feature. (gstack)
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

- **name**: 技能名称。用户输入 `/devex-review` 触发。
- **description**: 实时开发者体验审计。使用 browse 工具**实际测试**开发者体验：导航文档、尝试 getting started 流程、计时 TTHW、截图错误信息、评估 CLI 帮助文本。产出带证据的 DX 评分卡。如果存在 `/plan-devex-review` 的分数则进行对比（"回旋镖"：方案说 3 分钟，现实是 8 分钟）。
- **allowed-tools**: 注意有 **Edit**——这个技能可以改代码，用于记录和日志写入。**没有 Write**——不创建新文件，只编辑已有文件。

> **设计原理：为什么 devex-review 有 Edit，而 plan-devex-review 也有？**
> plan 阶段：Edit 用于修改方案文件。live 阶段：Edit 用于写入 CLAUDE.md 的 review 日志、更新 learnings。两者都不直接修改产品代码——DX 审计是诊断，不是治疗。

### devex-review vs plan-devex-review：根本区别

```
/plan-devex-review          /devex-review
  方案阶段（实现前）              实现后（上线后）
  预防为主                       事后诊断
  Interactive Q&A               自动化测试
  改方案文档                      截图为证
  估算 TTHW                     实测 TTHW
  设计 Magical Moment            验证是否实现
  8步审查 × 深度问答              8维评分 × 截图证据
  输出：修改后的方案               输出：DX Scorecard
```

---

## 技能定位与设计哲学

> **原文**：
> ```
> You are a DX engineer dogfooding a live developer product. Not reviewing a plan.
> Not reading about the experience. TESTING it.
> ```

**中文**：你是一名 DX 工程师，在亲身体验一个上线的开发者产品。不是审查方案。不是阅读体验报告。是**测试**它。

这一句话定义了整个技能的核心姿态。"Dogfooding"（吃自家狗粮）是硅谷术语，指团队自己使用自己的产品。gstack 要求 AI 真正模拟开发者的操作路径，而不是凭记忆或假设评分。

三个否定句的对比：

| 错误做法 | 正确做法 |
|---------|---------|
| 审查方案文档 | 打开真实的 docs URL |
| 读评论/报告 | 用 browse 工具导航 |
| 估算体验 | 截图 + 计时 |

> **设计原理：为什么要用 browse 工具？**
> 文本评审的盲区：你看不到视觉混乱、加载失败、破损的链接、误导性的 UI 布局。browse 截图让这些问题无处遁形。"证据"不是引用文件——是截图 URL 和 bash 输出。

---

## 第一部分：DX 第一性原理

> **原文**：
> ```
> ## DX First Principles
>
> These are the laws. Every recommendation traces back to one of these.
>
> 1. Zero friction at T0. First five minutes decide everything. One click to start.
>    Hello world without reading docs. No credit card. No demo call.
> 2. Incremental steps. Never force developers to understand the whole system before
>    getting value from one part. Gentle ramp, not cliff.
> 3. Learn by doing. Playgrounds, sandboxes, copy-paste code that works in context.
>    Reference docs are necessary but never sufficient.
> 4. Decide for me, let me override. Opinionated defaults are features. Escape hatches
>    are requirements. Strong opinions, loosely held.
> 5. Fight uncertainty. Developers need: what to do next, whether it worked, how to
>    fix it when it didn't. Every error = problem + cause + fix.
> 6. Show code in context. Hello world is a lie. Show real auth, real error handling,
>    real deployment. Solve 100% of the problem.
> 7. Speed is a feature. Iteration speed is everything. Response times, build times,
>    lines of code to accomplish a task, concepts to learn.
> 8. Create magical moments. What would feel like magic? Stripe's instant API response.
>    Vercel's push-to-deploy. Find yours and make it the first thing developers experience.
> ```

**中文翻译**：这是法律。每条建议都必须追溯到其中一条。

| # | 原则 | 中文解读 | 典型违反案例 |
|---|------|---------|------------|
| 1 | **T0 零摩擦** | 前 5 分钟决定一切。一键启动。不读文档也能 hello world。不要信用卡。不要 demo 通话。 | 注册需要企业邮件验证 + 等待审核 |
| 2 | **渐进式步骤** | 永远不要强迫开发者在获得第一个价值之前理解整个系统。温和斜坡，不是悬崖。 | "在开始之前，请先了解我们的架构..." |
| 3 | **动手学习** | Playground、沙箱、能在上下文中运行的复制粘贴代码。参考文档是必要的但永远不够。 | 只有 API 参考，没有可运行示例 |
| 4 | **替我决定，让我覆盖** | 有主见的默认值是特性。逃生通道是必须品。强观点，松持有。 | 每个配置项都强制用户选择 |
| 5 | **对抗不确定性** | 开发者需要：下一步做什么、是否成功、如何修复失败。每条错误 = 问题 + 原因 + 解决方案。 | `Error: undefined is not a function` |
| 6 | **在上下文中展示代码** | Hello world 是谎言。展示真实的 auth、真实的错误处理、真实的部署。解决 100% 的问题。 | 示例代码没有错误处理，没有 auth |
| 7 | **速度是特性** | 迭代速度就是一切。响应时间、构建时间、完成任务需要的代码行数、需要学习的概念数。 | SDK 初始化需要 200 行配置 |
| 8 | **创造魔法时刻** | 什么感觉像魔法？Stripe 的即时 API 响应。Vercel 的 push-to-deploy。找到你的魔法，让它成为开发者的第一体验。 | 产品没有"wow 时刻" |

> **设计原理：为什么有 8 条而不是 3 条？**
> 这 8 条覆盖了开发者体验的完整认知地图。删掉任何一条都会留下盲区。原则 1 覆盖"第一印象"，原则 2-3 覆盖"学习曲线"，原则 4-5 覆盖"错误恢复"，原则 6-7 覆盖"日常使用"，原则 8 覆盖"情感连接"。

---

## 第二部分：七个 DX 特征维度

> **原文**：
> ```
> ## The Seven DX Characteristics
>
> | # | Characteristic | What It Means                              | Gold Standard                    |
> |---|---------------|--------------------------------------------|----------------------------------|
> | 1 | Usable        | Simple to install, set up, use. Intuitive  | Stripe: one key, one curl, money |
> |   |               | APIs. Fast feedback.                        | moves                            |
> | 2 | Credible      | Reliable, predictable, consistent. Clear   | TypeScript: gradual adoption,    |
> |   |               | deprecation. Secure.                        | never breaks JS                  |
> | 3 | Findable      | Easy to discover AND find help within.     | React: every question answered   |
> |   |               | Strong community. Good search.              | on SO                            |
> | 4 | Useful        | Solves real problems. Features match        | Tailwind: covers 95% of CSS needs|
> |   |               | actual use cases. Scales.                   |                                  |
> | 5 | Valuable      | Reduces friction measurably. Saves time.   | Next.js: SSR, routing, bundling, |
> |   |               | Worth the dependency.                       | deploy in one                    |
> | 6 | Accessible    | Works across roles, environments,           | VS Code: works for junior to     |
> |   |               | preferences. CLI + GUI.                     | principal                        |
> | 7 | Desirable     | Best-in-class tech. Reasonable pricing.    | Vercel: devs WANT to use it,     |
> |   |               | Community momentum.                         | not tolerate it                  |
> ```

**中文**：七个 DX 特征框架

| # | 特征 | 含义 | 金标准 | 常见失分点 |
|---|------|------|--------|----------|
| 1 | **Usable（可用）** | 安装、设置、使用简单。直觉化 API。快速反馈。 | Stripe：一个 key，一行 curl，钱就转了 | 安装需要 5 个步骤，每步都可能失败 |
| 2 | **Credible（可信）** | 可靠、可预测、一致。清晰的废弃策略。安全。 | TypeScript：渐进式采用，永不破坏 JS | 版本升级经常 breaking change |
| 3 | **Findable（可发现）** | 容易发现，容易找到帮助。强社区。好搜索。 | React：每个问题在 Stack Overflow 都有答案 | 官方文档搜索功能不可用 |
| 4 | **Useful（有用）** | 解决真实问题。功能匹配实际用例。可扩展。 | Tailwind：覆盖 95% 的 CSS 需求 | 功能齐全但不匹配真实场景 |
| 5 | **Valuable（有价值）** | 可量化地减少摩擦。节省时间。值得依赖。 | Next.js：SSR + 路由 + 打包 + 部署一体化 | 引入工具比不引入还麻烦 |
| 6 | **Accessible（可及）** | 跨角色、跨环境、跨偏好可用。CLI + GUI。 | VS Code：初级到高级工程师都能用 | 只有 GUI，没有 CLI；只支持 Mac |
| 7 | **Desirable（令人向往）** | 一流技术。合理定价。社区势能。 | Vercel：开发者**想要**用，不是凑合用 | 技术上可以，但没人愿意推荐 |

> **设计原理：这个框架的来源**
> 这 7 个维度来自 DX 研究领域（参考 DX Core 4 等框架）。关键洞察是：大多数团队只优化"Usable"（前 3 条），却忽略了"Valuable"和"Desirable"。Desirable 是留存的关键——开发者工具如果只是"能用"，就会在更好的替代出现时立刻被抛弃。

---

## 第三部分：十个认知模式（DX 领导者的思维方式）

> **原文**：
> ```
> ## Cognitive Patterns — How Great DX Leaders Think
>
> Internalize these; don't enumerate them.
>
> 1. Chef-for-chefs — Your users build products for a living. The bar is higher because
>    they notice everything.
> 2. First five minutes obsession — New dev arrives. Clock starts. Can they hello-world
>    without docs, sales, or credit card?
> 3. Error message empathy — Every error is pain. Does it identify the problem, explain
>    the cause, show the fix, link to docs?
> 4. Escape hatch awareness — Every default needs an override. No escape hatch = no
>    trust = no adoption at scale.
> 5. Journey wholeness — DX is discover → evaluate → install → hello world → integrate
>    → debug → upgrade → scale → migrate. Every gap = a lost dev.
> 6. Context switching cost — Every time a dev leaves your tool (docs, dashboard, error
>    lookup), you lose them for 10-20 minutes.
> 7. Upgrade fear — Will this break my production app? Clear changelogs, migration
>    guides, codemods, deprecation warnings. Upgrades should be boring.
> 8. SDK completeness — If devs write their own HTTP wrapper, you failed. If the SDK
>    works in 4 of 5 languages, the fifth community hates you.
> 9. Pit of Success — "We want customers to simply fall into winning practices" (Rico
>    Mariani). Make the right thing easy, the wrong thing hard.
> 10. Progressive disclosure — Simple case is production-ready, not a toy. Complex case
>     uses the same API. SwiftUI: Button("Save") { save() } → full customization, same API.
> ```

**中文解读**：

这 10 个认知模式是 DX 工程师的内化思维，不是检查清单——它们是你审查产品时应该**自然使用**的视角。

**1. 厨师为厨师服务（Chef-for-chefs）**
开发者工具的用户是职业构建者。他们比普通用户更挑剔，因为他们整天跟工具打交道，细节上的不一致、矛盾的命名、多余的步骤——他们全都会注意到。

**2. 前五分钟执念（First five minutes obsession）**
新开发者到来时，时钟开始计时。他们能否在不看文档、不联系销售、不填信用卡的情况下完成 hello world？

```
T+0:00  开发者打开 README
T+0:30  找到安装命令
T+2:00  安装完成，尝试第一个命令
T+5:00  ← 如果到这里还没成功，大多数人放弃
```

**3. 错误信息同理心（Error message empathy）**
每条错误信息都是痛苦。好的错误信息模板：
```
[问题是什么]: 无法连接到数据库
[为什么]: 端口 5432 被拒绝，可能是防火墙或数据库未启动
[如何修复]: 检查 DATABASE_URL 是否正确，或运行 `docker compose up db`
[深入了解]: https://docs.example.com/troubleshoot/database
```

**4. 逃生通道意识（Escape hatch awareness）**
每个默认值都需要一个覆盖机制。没有逃生通道 = 没有信任 = 规模化时无法采用。  
典型例子：Stripe 的 `expand[]` 参数——默认返回 ID，但任何对象都可以展开。

**5. 旅程完整性（Journey wholeness）**
DX 是一段完整的旅程，每个环节都可能流失开发者：

```
发现 → 评估 → 安装 → Hello World → 集成 → 调试 → 升级 → 扩展 → 迁移
  ↑       ↑       ↑        ↑          ↑       ↑       ↑       ↑       ↑
 每个箭头都是一个潜在的流失点
```

**6. 上下文切换成本（Context switching cost）**
每次开发者离开你的工具（去查文档、去 Dashboard、去 Stack Overflow），你就失去他们 10-20 分钟。  
Stripe 的解决方案：把 API 密钥预填到文档里，把 Stripe Shell 嵌入文档页面——开发者永远不需要离开。

**7. 升级恐惧（Upgrade fear）**
"这会破坏我的生产应用吗？"是开发者最常见的升级顾虑。  
解决方案组合：语义化版本 + 废弃警告 + 迁移指南 + Codemods（自动化迁移脚本）。

**8. SDK 完整性（SDK completeness）**
如果开发者不得不自己写 HTTP 封装，你失败了。如果 SDK 在 5 门语言中支持 4 门，第五门的社区会恨你。

**9. 成功之坑（Pit of Success）**
引用 Rico Mariani 的名言："我们想让客户自然地落入正确实践中。" 把正确的事做成最简单的路径，把错误的事做成需要额外努力才能做到的路径。

**10. 渐进式披露（Progressive disclosure）**
简单情况应该是生产就绪的，不是玩具。复杂情况使用相同的 API。  
SwiftUI 的典范：`Button("Save") { save() }` 到完全自定义，同一个 API，逐层揭示复杂度。

---

## 第四部分：DX 评分标准（0-10 校准）

> **原文**：
> ```
> ## DX Scoring Rubric (0-10 calibration)
>
> | Score | Meaning                                                           |
> |-------|-------------------------------------------------------------------|
> | 9-10  | Best-in-class. Stripe/Vercel tier. Developers rave about it.      |
> | 7-8   | Good. Developers can use it without frustration. Minor gaps.      |
> | 5-6   | Acceptable. Works but with friction. Developers tolerate it.      |
> | 3-4   | Poor. Developers complain. Adoption suffers.                      |
> | 1-2   | Broken. Developers abandon after first attempt.                   |
> | 0     | Not addressed. No thought given to this dimension.                |
>
> The gap method: For each score, explain what a 10 looks like for THIS product.
> Then fix toward 10.
> ```

**中文解读**：

| 分数 | 含义 | 典型信号 | 行动 |
|------|------|---------|------|
| 9-10 | 最佳水准。Stripe/Vercel 级别。开发者主动推荐。 | "我告诉所有朋友用这个" | 维持，分析为何好 |
| 7-8 | 良好。开发者可以无挫败感地使用。有小问题。 | 能用，偶尔需要查文档 | 填补小缺口 |
| 5-6 | 可接受。能用但有摩擦。开发者勉强容忍。 | "能用，但不喜欢" | 中优先级修复 |
| 3-4 | 差。开发者抱怨。采用率受影响。 | 论坛有大量负面反馈 | 高优先级修复 |
| 1-2 | 损坏。开发者第一次尝试后就放弃。 | 评测: "根本无法完成 hello world" | 立刻停止发布，先修复 |
| 0 | 未处理。对这个维度没有任何考虑。 | 该维度完全缺失 | 从零开始设计 |

**差值法（Gap Method）**：不仅给出当前分数，还要说明"对于这个具体产品，10 分是什么样的"，然后向 10 分推进。这是 devex-review 的核心审计思路。

---

## 第五部分：TTHW 基准（Time to Hello World）

> **原文**：
> ```
> ## TTHW Benchmarks (Time to Hello World)
>
> | Tier      | Time     | Adoption Impact              |
> |-----------|----------|------------------------------|
> | Champion  | < 2 min  | 3-4x higher adoption         |
> | Competitive | 2-5 min | Baseline                    |
> | Needs Work | 5-10 min | Significant drop-off        |
> | Red Flag  | > 10 min | 50-70% abandon               |
> ```

**中文解读**：

TTHW 是 DX 的核心指标，是可以实际测量的。devex-review 通过 browse 工具**实测**，而 plan-devex-review 只能**估算**。

```
冠军级（< 2分钟）
  ▓▓▓▓▓▓▓▓▓▓  采用率 3-4x 基准
  代表产品：Stripe（30秒）、Clerk（3 JSX 组件）

竞争级（2-5分钟）
  ▓▓▓▓▓▓▓     基准线
  代表产品：Vercel（git push）、Firebase（onSnapshot）

待改进（5-10分钟）
  ▓▓▓▓        采用率显著下降
  常见原因：多步骤配置、需要账号

红色警报（> 10分钟）
  ▓▓          50-70% 的开发者放弃
  常见原因：要求信用卡、需要 demo 通话
```

> **设计原理：为什么 2 分钟是关键阈值？**
> 来自 YC 合伙人的实战观察：2 分钟是开发者的"无需思考"阈值。低于 2 分钟，开发者会继续。超过 2 分钟，他们开始计算"值不值得"。这跟人类注意力窗口有关，不是任意数字。

---

## 第六部分：DX 八步审计流程

整个审计分为 8 步，每步都有：测试方法（TESTED/INFERRED/PARTIAL）、证据来源（截图/文件引用）、0-10 评分。

```
           ┌─────────────────────────────────┐
           │    /devex-review 执行流程         │
           └─────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │ Step 0      │
                    │ 目标发现    │  读 CLAUDE.md/README
                    │ + 回旋镖    │  检查先前 plan-devex 评分
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────────────┐
           │               │                       │
    ┌──────▼──────┐  ┌─────▼──────┐  ┌─────────────▼──────┐
    │ Step 1-4   │  │ Step 5-6  │  │ Step 7-8           │
    │ 可见面测试  │  │ 文件推断  │  │ 社区+度量          │
    │ (TESTED)   │  │(INFERRED) │  │ (TESTED/INFERRED)  │
    └──────┬──────┘  └─────┬──────┘  └─────────────┬──────┘
           └───────────────┼───────────────────────┘
                           │
                    ┌──────▼──────┐
                    │ DX Scorecard│
                    │ 八维评分卡  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ 回旋镖对比  │  Plan 分数 vs Live 分数
                    │ (如果有)    │  Delta > 2 = 警报
                    └─────────────┘
```

### Step 0：目标发现 + 回旋镖基线

> **原文**：
> ```
> ## Step 0: Target Discovery
>
> 1. Read CLAUDE.md for project URL, docs URL, CLI install command
> 2. Read README.md for getting started instructions
> 3. Read package.json or equivalent for install commands
>
> ### Boomerang Baseline
>
> Check for prior /plan-devex-review scores:
> eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
> ~/.claude/skills/gstack/bin/gstack-review-read 2>/dev/null | grep plan-devex-review
> ```

**"回旋镖"机制（Boomerang）**是 devex-review 最核心的设计亮点。

```
时间线：

方案阶段                        实现后
   │                              │
   ▼                              ▼
/plan-devex-review            /devex-review
  估算 TTHW: 3 min               实测 TTHW: 8 min
  Getting Started: 8/10          Getting Started: 5/10
  Error Messages: 7/10           Error Messages: 4/10
                                        │
                                        ▼
                               ⚠️  BOOMERANG ALERT
                               方案承诺 vs 现实差距
```

"回旋镖"的含义：你在方案阶段做了预期评分，实现后再来测，看预期与现实的差距有多大。差距超过 2 分就是警报——说明方案要么过于乐观，要么实现没有兑现承诺。

### Step 1：Getting Started 审计

> **原文**：
> ```
> GETTING STARTED AUDIT
> =====================
> Step 1: [what dev does]  Time: [est]  Friction: [low/med/high]  Evidence: [screenshot/bash output]
> Step 2: [what dev does]  Time: [est]  Friction: [low/med/high]  Evidence: [screenshot/bash output]
> TOTAL: [N steps, M minutes]
> ```

这个格式的精妙之处：每步都要记录**证据来源**。截图 URL 或 bash 输出——不是猜测，不是印象。

### Step 2：API/CLI/SDK 人体工程学审计

测试内容：
- CLI：通过 bash 运行 `--help`，评估输出质量、flag 设计、可发现性
- API playground：通过 browse 导航（如果存在）并截图
- 命名一致性：检查整个 API 表面的命名规律

### Step 3：错误信息审计

触发常见错误场景：
- Browse：导航到 404 页面、提交无效表单、尝试未认证访问
- CLI：用缺失参数、无效 flag、错误输入运行

**三层错误质量模型**（来自 dx-hall-of-fame.md）：

```
Tier 1 — Elm（对话式编译器）：
  第一人称、完整句子、精确位置、建议修复、扩展阅读
  "I cannot do addition with String values..."

Tier 2 — Rust（标注源码）：
  错误代码链接到教程、主要+次要标签、帮助区显示精确编辑
  "error[E0308]: mismatched types"

Tier 3 — Stripe API（结构化 + doc_url）：
  {"type":"invalid_request_error","code":"resource_missing",
   "message":"No such customer","doc_url":"..."}
```

### Step 4：文档审计

通过 browse 测试：
- 搜索功能（尝试 3 个常见查询）
- 验证代码示例是否可以完整复制粘贴
- 检查语言切换行为
- 检查信息架构（2 分钟内能找到需要的内容吗？）

### Step 5：升级路径审计（INFERRED）

通过 bash 读取：
- CHANGELOG 质量（清晰？面向用户？迁移说明？）
- 迁移指南（存在？逐步说明？）
- 代码中的废弃警告

这一步标记为 **INFERRED**（推断），因为 browse 无法测试升级流程，只能从文件推断。

### Step 6：开发者环境审计（INFERRED）

通过 bash 读取：
- README 设置指令（步骤数？前提条件？平台覆盖？）
- CI/CD 配置
- TypeScript 类型（如适用）
- 测试工具/fixture

### Step 7：社区与生态审计（TESTED）

通过 browse 测试：
- 社区链接（GitHub Discussions、Discord、Stack Overflow）
- GitHub issues（响应时间、模板、标签）
- 贡献指南

### Step 8：DX 度量审计

检查反馈机制：
- Bug 报告模板
- NPS 或反馈组件
- 文档上的分析工具

---

## 第七部分：DX Scorecard（评分卡）

> **原文**：
> ```
> +====================================================================+
> |              DX LIVE AUDIT — SCORECARD                              |
> +====================================================================+
> | Dimension            | Score  | Evidence | Method   |
> |----------------------|--------|----------|----------|
> | Getting Started      | __/10  | [screenshots] | TESTED   |
> | API/CLI/SDK          | __/10  | [screenshots] | PARTIAL  |
> | Error Messages       | __/10  | [screenshots] | PARTIAL  |
> | Documentation        | __/10  | [screenshots] | TESTED   |
> | Upgrade Path         | __/10  | [file refs]   | INFERRED |
> | Dev Environment      | __/10  | [file refs]   | INFERRED |
> | Community            | __/10  | [screenshots] | TESTED   |
> | DX Measurement       | __/10  | [file refs]   | INFERRED |
> +--------------------------------------------------------------------+
> | TTHW (measured)      | __ min | [step count]  | TESTED   |
> | Overall DX           | __/10  |               |          |
> +====================================================================+
> ```

**中文解读**：评分卡的设计亮点——**三列强制透明**

| 维度 | 分数 | 证据 | 方法 |
|------|------|------|------|
| Getting Started | 评分 | 截图 URL | **TESTED** = 实际用 browse 测试 |
| API/CLI/SDK | 评分 | 截图 | **PARTIAL** = 部分测试，部分推断 |
| Error Messages | 评分 | 截图 | **PARTIAL** |
| Documentation | 评分 | 截图 | **TESTED** |
| Upgrade Path | 评分 | 文件引用 | **INFERRED** = 从文件推断，未直接测试 |
| Dev Environment | 评分 | 文件引用 | **INFERRED** |
| Community | 评分 | 截图 | **TESTED** |
| DX Measurement | 评分 | 文件引用 | **INFERRED** |

> **设计原理：为什么区分 TESTED / PARTIAL / INFERRED？**
> 诚实是 DX 审计的基础。browse 工具有局限——它无法测试本地安装摩擦、终端输出质量、离线行为。强制标注方法，就是强制承认局限性，防止 AI 把"我猜测"当成"我测试了"。这保护了评分的可信度。

---

## 第八部分：回旋镖对比

> **原文**：
> ```
> PLAN vs REALITY
> ================
> | Dimension        | Plan Score | Live Score | Delta | Alert |
> |------------------|-----------|-----------|-------|-------|
> | Getting Started  | __/10     | __/10     | __    | ⚠/✓  |
> | API/CLI/SDK      | __/10     | __/10     | __    | ⚠/✓  |
> ...
> | TTHW             | __ min    | __ min    | __ min| ⚠/✓  |
>
> Flag any dimension where live score < plan score - 2 (reality fell short of plan).
> ```

**回旋镖对比的触发条件**：当 live score < plan score - 2 时，触发警报（⚠）。

```
例子：
  Getting Started: 方案 8/10 → 现实 5/10   Delta: -3  ⚠ 警报
  Error Messages:  方案 7/10 → 现实 6/10   Delta: -1  ✓ 可接受
  TTHW:           方案 3min  → 现实 8min   Delta: +5  ⚠ 严重差距
```

这个机制有三个价值：
1. **问责**：让方案中的乐观估计有代价
2. **校准**：帮助团队学会做更准确的 DX 预测
3. **优先级**：差距最大的维度 = 最需要立刻修复的地方

---

## 第九部分：证据来源与测试边界

> **原文**：
> ```
> ## Scope Declaration
>
> Browse can test: docs pages, API playgrounds, web dashboards, signup flows,
> interactive tutorials, error pages.
>
> Browse CANNOT test: CLI install friction, terminal output quality, local environment
> setup, email verification flows, auth requiring real credentials, offline behavior,
> build times, IDE integration.
>
> For untestable dimensions, use bash (for CLI --help, README, CHANGELOG) or mark as
> INFERRED from artifacts. Never guess. State your evidence source for every score.
> ```

**中文**：这是 devex-review 的诚实边界声明。

| 可以测试（TESTED） | 不能测试，用 bash | 不能测试，标 INFERRED |
|------------------|-----------------|-------------------|
| 文档页面 | CLI `--help` 输出 | CLI 安装摩擦 |
| API playground | README 内容 | 本地环境设置 |
| Web Dashboard | CHANGELOG | 邮件验证流程 |
| 注册流程 | package.json | 真实认证 |
| 交互式教程 | 测试文件 | 离线行为 |
| 错误页面 | CI 配置 | 构建时间 |

---

## 第十部分：Review Log 与 Dashboard

审计完成后，结果持久化到 review log，用于追踪 DX 趋势：

```bash
~/.claude/skills/gstack/bin/gstack-review-log '{"skill":"devex-review","timestamp":"...","status":"...","overall_score":N,"tthw_measured":"...","boomerang":"YES_OR_NO"}'
```

**Review Readiness Dashboard** 显示所有审查的状态：

```
+====================================================================+
|                    REVIEW READINESS DASHBOARD                       |
+====================================================================+
| Review          | Runs | Last Run            | Status    | Required |
|-----------------|------|---------------------|-----------|----------|
| Eng Review      |  1   | 2026-03-16 15:00    | CLEAR     | YES      |
| DX Review       |  1   | 2026-04-01 10:00    | CLEAR     |          |
| Design Review   |  0   | —                   | —         | no       |
+--------------------------------------------------------------------+
| VERDICT: CLEARED — Eng Review passed                                |
+====================================================================+
```

---

## 第十一部分：Learnings（经验积累）

> **原文**：
> ```
> ## Capture Learnings
>
> If you discovered a non-obvious pattern, pitfall, or architectural insight during
> this session, log it for future sessions...
> ```

devex-review 支持跨 session 的学习积累。每次发现非显而易见的模式或陷阱，就记录到 learnings：

```bash
~/.claude/skills/gstack/bin/gstack-learnings-log '{
  "skill":"devex-review",
  "type":"pitfall",
  "key":"getting-started-auth-wall",
  "insight":"This product requires creating an account before any API call. TTHW is 8min not 3min.",
  "confidence":9,
  "source":"observed"
}'
```

类型（type）：
- `pattern`：可复用的方法
- `pitfall`：不要做什么
- `preference`：用户明确说的偏好
- `architecture`：结构性决策
- `operational`：项目环境/CLI/工作流知识

---

## 第十二部分：完整工作流汇总

```
/devex-review 完整执行流程
==============================

1. 运行 Preamble（bash）
   - 检查 gstack 更新
   - 记录 session 开始
   - 获取 branch 名称

2. Step 0：目标发现
   - 读 CLAUDE.md / README.md
   - 检查 plan-devex-review 历史分数（回旋镖基线）

3. Steps 1-8：八维审计
   Step 1: Getting Started (browse + 计时)
   Step 2: API/CLI/SDK (browse + bash --help)
   Step 3: Error Messages (browse 触发错误场景)
   Step 4: Documentation (browse 导航 + 搜索测试)
   Step 5: Upgrade Path (bash 读 CHANGELOG)
   Step 6: Dev Environment (bash 读 README/CI 配置)
   Step 7: Community (browse GitHub/Discord)
   Step 8: DX Measurement (bash 读反馈机制)

4. 产出 DX Scorecard
   - 八维评分 + 证据 + 方法标注

5. 回旋镖对比（如有历史 plan 分数）
   - 计算 Delta，标注差距 > 2 的维度

6. 持久化 Review Log

7. 显示 Review Readiness Dashboard

8. 记录 Learnings（如有新发现）

9. 建议后续步骤（修复 + 重测）

10. 运行 Telemetry（bash，记录时长和结果）
```

---

## 第十三部分：与其他技能的关系

```
技能生态系统中的 devex-review 位置：

/office-hours ──────►  产品创意验证
      │
      ▼
/plan-devex-review ─►  方案阶段 DX 审查（实现前）
      │                预估分数 + 方案修改
      │
      ▼ [实现代码]
      │
/devex-review ──────►  实测 DX（实现后）
      │                实测分数 + 回旋镖对比
      │
      ▼
/qa ────────────────►  用户体验 QA（不同角度）
      │                qa 关注最终用户，devex 关注开发者
      │
      ▼
/review ────────────►  代码层面审查（diff 级别）
```

| 技能 | 审查对象 | 时机 | 输出 |
|------|---------|------|------|
| `/plan-devex-review` | 方案文档 | 编码前 | 修改后的方案 |
| `/devex-review` | 上线产品 | 发布后 | DX Scorecard |
| `/qa` | 最终用户体验 | 发布前后 | Bug 报告 |
| `/review` | 代码 diff | 合并前 | 代码审查意见 |
| `/plan-eng-review` | 架构方案 | 编码前 | 修改后的架构 |

---

## 第十四部分：格式规则

> **原文**：
> ```
> ## Formatting Rules
>
> * NUMBER issues (1, 2, 3...) and LETTERS for options (A, B, C...).
> * Rate every dimension with evidence source.
> * Screenshots are the gold standard. File references are acceptable. Guesses are not.
> ```

**中文**：
- 问题用数字编号（1, 2, 3...），选项用字母（A, B, C...）
- 每个维度的评分都必须附带证据来源
- 截图是黄金标准。文件引用可以接受。猜测不可接受。

---

## 总结：devex-review 的核心价值

1. **测量而非猜测**：browse 工具让 DX 评分有截图为证
2. **回旋镖问责**：方案承诺与现实对比，差距无处遁形
3. **证据透明**：强制标注 TESTED / PARTIAL / INFERRED，诚实陈述局限
4. **TTHW 量化**：把"开发者体验好"从感受变成可测量的分钟数
5. **Hall of Fame 校准**：对照 Stripe/Vercel/Elm 等最佳实践，避免"感觉不错但没到标准"

> **一句话定位**：devex-review 是面向开发者产品的"亲身体验审计"，用 browse 工具模拟真实开发者的操作路径，用截图证据而非感觉来评分，用回旋镖机制把方案预期与现实对齐。
