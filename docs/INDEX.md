# gstack-zh 文档索引

gstack 中文深度注解学习指南。文档分两层：**实现原理**（理解 gstack 怎么工作）和 **技能注解**（理解每个 /skill 命令做什么）。

---

## 实现原理

理解 gstack 的设计哲学和内部机制，按推荐阅读顺序排列：

| 文档 | 内容 | 阅读时机 |
|------|------|---------|
| [architecture.md](architecture.md) | 整体架构：无头浏览器守护进程、Bun 选型、目录结构 | 入门首读 |
| [how-skills-work.md](how-skills-work.md) | Skill 系统：SKILL.md 格式、frontmatter 字段、模板变量、编写规范 | 理解"技能是什么" |
| [template-pipeline.md](template-pipeline.md) | 模板编译管线：`.tmpl` → `SKILL.md`，resolver 架构，多平台生成 | 理解"技能怎么编译" |
| [runtime-internals.md](runtime-internals.md) | 运行时内部：Preamble 系统（9 步状态收集）+ `~/.gstack/` 状态存储（JSONL/slug/learnings） | 理解"技能启动时做什么" |
| [ship-workflow.md](ship-workflow.md) | `/ship` 端到端：完整 20+ 步骤、Test Failure Ownership Triage、Review Dashboard、PR body 结构 | 理解最复杂的 skill |
| [methodology.md](methodology.md) | gstack 研发方法论：从 /autoplan 到 /ship 的完整开发闭环，各阶段 artifacts | 理解 gstack 的工程实践 |
| [browse-daemon.md](browse-daemon.md) | Browse 守护进程源码解读：`$B` 命令背后的无头浏览器实现 | 深入 browse 子系统 |
| [design-binary.md](design-binary.md) | Design 二进制源码解读：`$D` 命令背后的设计工具实现 | 深入 design 子系统 |
| [workflow-steps.md](workflow-steps.md) | **完整需求开发工作流**：web + 后端需求从 /office-hours 到 /ship 的逐步操作手册 | 开发新需求前读 |
| [company-lib-guide.md](company-lib-guide.md) | **公司库构建指南**：基于 gstack 源码分析，提炼"可直接复用"和"必须重新设计"的决策 | 准备自建类似库时读 |

---

## 技能注解（`docs/skills/`）

38 个技能的逐段中英对照注解。每个文件对应一个 `/skill` 命令，结构：英文原文（`> **原文**:` 块引用）+ 中文翻译 + 设计原理解读。

### 核心技能

| 技能 | 文件 | 用途 |
|------|------|------|
| `/ship` | [ship.md](skills/ship.md) | 完整 ship 工作流：测试、review、VERSION、PR |
| `/review` | [review.md](skills/review.md) | Code review：diff 分析、eng review |
| `/autoplan` | [autoplan.md](skills/autoplan.md) | 规划：CEO plan、多维 review 管线 |
| `/plan-eng-review` | [plan-eng-review.md](skills/plan-eng-review.md) | 工程架构评审（ship 的必须 gate） |
| `/investigate` | [investigate.md](skills/investigate.md) | Bug 调查：root cause 分析 |
| `/qa` | [qa.md](skills/qa.md) | 全面 QA：功能、边界、回归 |
| `/checkpoint` | [checkpoint.md](skills/checkpoint.md) | 跨 session 进度保存/恢复 |

### 规划类

| 技能 | 文件 | 用途 |
|------|------|------|
| `/plan-ceo-review` | [plan-ceo-review.md](skills/plan-ceo-review.md) | 产品/策略评审（CEO 视角） |
| `/plan-design-review` | [plan-design-review.md](skills/plan-design-review.md) | 设计评审（全面 UI/UX） |
| `/plan-devex-review` | [plan-devex-review.md](skills/plan-devex-review.md) | 开发体验评审（DX 视角） |
| `/office-hours` | [office-hours.md](skills/office-hours.md) | 产品讨论：想法碰撞、值不值得做 |

### 设计类

| 技能 | 文件 | 用途 |
|------|------|------|
| `/design-consultation` | [design-consultation.md](skills/design-consultation.md) | 设计系统：品牌、组件、色彩 |
| `/design-review` | [design-review.md](skills/design-review.md) | 视觉审查：可用性测试、设计 polish |
| `/design-html` | [design-html.md](skills/design-html.md) | HTML 原型生成 |
| `/design-shotgun` | [design-shotgun.md](skills/design-shotgun.md) | 多方案快速探索 |

### 工程工具类

| 技能 | 文件 | 用途 |
|------|------|------|
| `/browse` | [browse.md](skills/browse.md) | 无头浏览器操作（`$B` 命令） |
| `/codex` | [codex.md](skills/codex.md) | Codex 集成（outside voice、adversarial review） |
| `/health` | [health.md](skills/health.md) | 代码库健康检查 |
| `/retro` | [retro.md](skills/retro.md) | 周复盘：learnings 整理 |
| `/document-release` | [document-release.md](skills/document-release.md) | ship 后文档更新 |
| `/learn` | [learn.md](skills/learn.md) | 手动存入 learnings |
| `/benchmark` | [benchmark.md](skills/benchmark.md) | 性能基准测试 |

### 部署/流程类

| 技能 | 文件 | 用途 |
|------|------|------|
| `/land-and-deploy` | [land-and-deploy.md](skills/land-and-deploy.md) | PR merge + 部署流水线 |
| `/setup-deploy` | [setup-deploy.md](skills/setup-deploy.md) | 部署环境初始化 |
| `/freeze` / `/unfreeze` | [freeze.md](skills/freeze.md) / [unfreeze.md](skills/unfreeze.md) | 代码冻结/解冻 |
| `/canary` | [canary.md](skills/canary.md) | 金丝雀发布 |
| `/guard` | [guard.md](skills/guard.md) | 防护规则：自动拦截危险操作 |
| `/careful` | [careful.md](skills/careful.md) | 谨慎模式：Bash 命令执行前确认 |

### 管理类

| 技能 | 文件 | 用途 |
|------|------|------|
| `/gstack-root` | [gstack-root.md](skills/gstack-root.md) | gstack 总览：所有技能速查 |
| `/gstack-upgrade` | [gstack-upgrade.md](skills/gstack-upgrade.md) | 升级到最新版本 |
| `/cso` | [cso.md](skills/cso.md) | Chief Security Officer 安全审查 |
| `/devex-review` | [devex-review.md](skills/devex-review.md) | DX 审查（非 plan 阶段） |
| `/qa-only` | [qa-only.md](skills/qa-only.md) | 仅 QA，不 ship |
| `/pair-agent` | [pair-agent.md](skills/pair-agent.md) | 多 agent 协作 |
| `/open-gstack-browser` | [open-gstack-browser.md](skills/open-gstack-browser.md) | 打开 gstack 浏览器界面 |
| `/setup-browser-cookies` | [setup-browser-cookies.md](skills/setup-browser-cookies.md) | 配置浏览器 cookies |
| `/contrib-add-host` | [contrib-add-host.md](skills/contrib-add-host.md) | 为 gstack 新增 AI 平台支持 |

---

## 阅读路径建议

### 想理解"gstack 是什么"

1. [architecture.md](architecture.md) — 整体概念
2. [how-skills-work.md](how-skills-work.md) — skill 的工作方式
3. [gstack-root.md](skills/gstack-root.md) — 所有技能速查

### 想理解"gstack 怎么实现的"

1. [template-pipeline.md](template-pipeline.md) — 编译管线
2. [runtime-internals.md](runtime-internals.md) — 运行时机制
3. [ship-workflow.md](ship-workflow.md) — 最复杂 skill 的完整实现

### 想基于 gstack 构建公司工具库

1. [runtime-internals.md](runtime-internals.md) — 理解状态系统（要复用的部分）
2. [ship-workflow.md](ship-workflow.md) — 理解最完整的 workflow 设计
3. [company-lib-guide.md](company-lib-guide.md) — 构建决策指南

### 想深入某个技能

直接找对应的 `docs/skills/*.md`。
