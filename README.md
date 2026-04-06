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
| 设计师 | `/plan-design-review`, `/design-review` | 发现 UI 不一致，生成设计变体 |
| QA Lead | `/qa`, `/qa-only` | 打开真实浏览器，系统性测试 |
| 安全官 | `/cso` | OWASP Top 10 + STRIDE 审计 |
| 发布工程师 | `/review`, `/ship`, `/land-and-deploy` | PR 评审、版本发布、部署验证 |
| 调试专家 | `/investigate` | 系统性根因分析 |

---

## 文档导航

| 文档 | 内容 |
|------|------|
| [docs/architecture.md](./docs/architecture.md) | 架构解读：无头浏览器守护进程、Bun 选型、模板系统 |
| [docs/how-skills-work.md](./docs/how-skills-work.md) | 技能模板系统深度解析：9 个模板变量全解读 |
| [docs/skills/plan-eng-review.md](./docs/skills/plan-eng-review.md) | `/plan-eng-review` 技能逐行中英对照注解 |

更多技能注解持续更新中...

---

## 阅读建议

**如果你想用 gstack**：直接看[官方 README](https://github.com/garrytan/gstack)，按 Quick Start 安装即可。

**如果你想学习 gstack 的设计思路**：
1. 先读 [how-skills-work.md](./docs/how-skills-work.md)，理解技能是什么
2. 再读 [skills/plan-eng-review.md](./docs/skills/plan-eng-review.md)，看完整技能的设计逻辑
3. 最后读 [architecture.md](./docs/architecture.md)，理解浏览器层的技术决策

---

## 同步状态

当前对应 gstack 版本：见 [SYNC.md](./SYNC.md)

本仓库跟随 gstack minor/major 版本发布更新（~每 1-2 周一次）。
GitHub Actions 自动监听上游发版，开 issue 提醒同步。

---

## 重要说明

- 本文档**不是官方文档**，由社区贡献，可能落后于最新代码
- 如发现不准确之处，以英文源码为准
- 技能文件（`SKILL.md`）是发给 Claude 的 prompt，翻译它们会影响 AI 行为，因此本文档仅作解读，不修改原文
- ETHOS.md 是 Garry 的个人构建哲学，本仓库不翻译或改写，仅做注解解读
- Annotations by [@shengbinxu](https://github.com/shengbinxu). Original gstack MIT licensed.

---

## 贡献

欢迎提 PR 补充其他技能的注解。请确保：
1. 不修改任何英文原文（原文仅做引用）
2. 注解聚焦"为什么这样设计"，而不只是翻译"这里写了什么"
3. 每个技能注解文件放在 `docs/skills/<skill-name>.md`
