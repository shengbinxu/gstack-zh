# gstack 中文深度注解学习指南

> Chinese annotated guide to [garrytan/gstack](https://github.com/garrytan/gstack) — an open-source AI workflow toolkit by Garry Tan (YC CEO).

**这不是翻译仓库，是注解学习指南。**

每一篇文档保留英文原文结构，加入：
- 中文翻译对照
- 设计原理解读（"为什么这样写"，而不只是"这里写了什么"）
- ASCII 流程图可视化
- 中国开发者语境下的实际应用示例

---

## gstack 是什么？

gstack 是一套运行在 **Claude Code** 上的 AI 工作流技能集合，MIT 开源。

核心主张：一个配备正确工具的独立开发者，可以比传统团队移动更快。把 Claude Code 变成一支"虚拟工程团队"：

| 角色 | 技能命令 | 职责 |
|------|----------|------|
| CEO/产品顾问 | `/office-hours`, `/plan-ceo-review` | 重新思考问题，找到更好的产品方向 |
| 工程经理 | `/plan-eng-review` | 锁定架构，评审代码质量、测试、性能 |
| 设计师 | `/plan-design-review`, `/design-review`, `/design-shotgun` | 发现 UI 不一致，生成设计变体 |
| QA Lead | `/qa`, `/qa-only` | 打开真实浏览器，系统性测试 |
| 安全官 | `/cso` | OWASP Top 10 + STRIDE 审计 |
| 发布工程师 | `/review`, `/ship`, `/land-and-deploy` | PR 评审、版本发布、部署验证 |
| 调试专家 | `/investigate` | 系统性根因分析 |
| 浏览器工具 | `/browse` | 无头浏览器，持久化会话 |
| DX 工程师 | `/plan-devex-review`, `/devex-review` | 开发者体验审计 |

---

## 文档导航

### 架构与原理

| 文档 | 内容 |
|------|------|
| [architecture.md](./docs/architecture.md) | 架构解读：无头浏览器守护进程、Bun 选型、模板系统 |
| [how-skills-work.md](./docs/how-skills-work.md) | 技能模板系统深度解析：9 个模板变量全解读 |

### 全部 37 个技能注解

#### 产品与策略

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/office-hours` | [注解](./docs/skills/office-hours.md) | YC Office Hours：6个逼问诊断产品 |
| `/plan-ceo-review` | [注解](./docs/skills/plan-ceo-review.md) | CEO 视角评审：重新思考问题 |
| `/autoplan` | [注解](./docs/skills/autoplan.md) | 一条命令跑完全部评审 |

#### 工程评审

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/plan-eng-review` | [注解](./docs/skills/plan-eng-review.md) | 工程经理评审：架构+测试+性能 |
| `/review` | [注解](./docs/skills/review.md) | Pre-Landing PR 评审 |
| `/codex` | [注解](./docs/skills/codex.md) | OpenAI Codex 第二意见 |

#### 设计

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/design-consultation` | [注解](./docs/skills/design-consultation.md) | 从零创建设计系统 |
| `/plan-design-review` | [注解](./docs/skills/plan-design-review.md) | 设计师视角方案评审 |
| `/design-review` | [注解](./docs/skills/design-review.md) | Live 站点视觉 QA + 修复 |
| `/design-shotgun` | [注解](./docs/skills/design-shotgun.md) | 多方向视觉探索 |
| `/design-html` | [注解](./docs/skills/design-html.md) | 设计到生产级 HTML |

#### 测试与质量

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/qa` | [注解](./docs/skills/qa.md) | 浏览器 QA：测试+修复+验证 |
| `/qa-only` | [注解](./docs/skills/qa-only.md) | 只报告不修复的 QA |
| `/benchmark` | [注解](./docs/skills/benchmark.md) | 性能回归检测 |
| `/health` | [注解](./docs/skills/health.md) | 代码质量仪表盘 |

#### 调试

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/investigate` | [注解](./docs/skills/investigate.md) | 系统性根因调试 |

#### 发布与部署

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/ship` | [注解](./docs/skills/ship.md) | 全自动发布流程 |
| `/land-and-deploy` | [注解](./docs/skills/land-and-deploy.md) | 合并+部署+验证 |
| `/canary` | [注解](./docs/skills/canary.md) | 部署后金丝雀监控 |
| `/document-release` | [注解](./docs/skills/document-release.md) | 发布后文档更新 |

#### 开发者体验

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/plan-devex-review` | [注解](./docs/skills/plan-devex-review.md) | DX 方案评审 |
| `/devex-review` | [注解](./docs/skills/devex-review.md) | Live DX 审计 |

#### 安全

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/cso` | [注解](./docs/skills/cso.md) | 首席安全官审计 |

#### 工具与安全模式

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/browse` | [注解](./docs/skills/browse.md) | 无头浏览器基础工具 |
| `/open-gstack-browser` | [注解](./docs/skills/open-gstack-browser.md) | 可见 AI 浏览器 |
| `/setup-browser-cookies` | [注解](./docs/skills/setup-browser-cookies.md) | 导入浏览器 Cookie |
| `/setup-deploy` | [注解](./docs/skills/setup-deploy.md) | 配置部署 |
| `/careful` | [注解](./docs/skills/careful.md) | 破坏性命令守卫 |
| `/freeze` | [注解](./docs/skills/freeze.md) | 目录编辑限制 |
| `/unfreeze` | [注解](./docs/skills/unfreeze.md) | 解除编辑限制 |
| `/guard` | [注解](./docs/skills/guard.md) | 最大安全模式 |

#### 知识管理

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| `/checkpoint` | [注解](./docs/skills/checkpoint.md) | 保存/恢复工作状态 |
| `/learn` | [注解](./docs/skills/learn.md) | 管理项目学习记录 |
| `/retro` | [注解](./docs/skills/retro.md) | 工程周回顾 |

#### 系统

| 技能 | 注解 | 一句话说明 |
|------|------|-----------|
| gstack（根） | [注解](./docs/skills/gstack-root.md) | 技能路由入口 |
| `/gstack-upgrade` | [注解](./docs/skills/gstack-upgrade.md) | 升级 gstack |
| `/gstack-contrib-add-host` | [注解](./docs/skills/contrib-add-host.md) | 贡献者：添加新 AI agent 支持 |

---

## 阅读建议

**如果你想用 gstack**：直接看[官方 README](https://github.com/garrytan/gstack)，按 Quick Start 安装即可。

**如果你想学习 gstack 的设计思路**：
1. 先读 [how-skills-work.md](./docs/how-skills-work.md)，理解技能是什么
2. 再读 [skills/plan-eng-review.md](./docs/skills/plan-eng-review.md)，看完整技能的设计逻辑
3. 最后读 [architecture.md](./docs/architecture.md)，理解浏览器层的技术决策

**如果你想快速浏览所有技能**：看上面的导航表，每个技能有一句话说明。

---

## 同步状态

当前对应 gstack 版本：见 [SYNC.md](./SYNC.md)

本仓库跟随 gstack minor/major 版本发布更新（~每 1-2 周一次）。
GitHub Actions 自动监听上游发版，开 issue 提醒同步。

---

## 重要说明

- 本文档**不是官方文档**，由社区贡献，可能落后于最新代码
- 如发现不准确之处，以英文源码为准
- 技能文件（`SKILL.md`）是发给 Claude 的 prompt，翻译它们会影响 AI 行为，因此本文档仅作解读
- ETHOS.md 是 Garry 的个人构建哲学，本仓库不翻译或改写，仅做注解解读
- Annotations by [@shengbinxu](https://github.com/shengbinxu). Original gstack MIT licensed.

---

## 贡献

欢迎提 PR 补充或改进注解。请确保：
1. 不修改任何英文原文（原文仅做引用）
2. 注解聚焦"为什么这样设计"，而不只是翻译"这里写了什么"
3. 每个技能注解文件放在 `docs/skills/<skill-name>.md`
