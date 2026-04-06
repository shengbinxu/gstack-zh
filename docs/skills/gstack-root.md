# gstack 根技能深度注解

> 对应源文件：[`SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/SKILL.md.tmpl)（仓库根目录）
> 这是 gstack 的路由入口：把用户请求分发到正确的技能。

## 核心定位

这不是一个"做事"的技能，而是路由器。当用户安装 gstack 后，这个技能被 Claude Code 自动加载，负责：

1. **Proactive 模式检测**：如果用户关闭了主动推荐，只响应显式调用
2. **技能路由**：根据用户意图匹配到正确的技能

## 路由规则

| 用户意图 | 路由到 |
|---------|--------|
| 新想法、头脑风暴 | /office-hours |
| 策略评审、范围 | /plan-ceo-review |
| 架构评审 | /plan-eng-review |
| 设计系统 | /design-consultation |
| 设计评审 | /plan-design-review 或 /design-review |
| 全部评审 | /autoplan |
| Bug、错误 | /investigate |
| QA 测试 | /qa |
| 代码评审 | /review |
| 发布、PR | /ship |
| 文档更新 | /document-release |
| 周回顾 | /retro |
| 安全审计 | /cso |
| 升级 | /gstack-upgrade |

## 核心规则

```
如果有匹配的技能 → 不要直接回答，调用技能
技能提供结构化、多步骤工作流，永远比即席回答更好
```
