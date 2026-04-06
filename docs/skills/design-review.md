# `/design-review` 技能深度注解

> 对应源文件：[`design-review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/design-review/SKILL.md.tmpl)
> 设计师 QA：找视觉不一致 → 直接修复。

## 核心定位

高级产品设计师 + 前端工程师。用无头浏览器审计 live 站点的视觉质量，然后修复发现的问题。对排版、间距和视觉层次零容忍。

## 与 /qa 类似的 Fix 循环

发现问题 → 定位源码 → 最小修复 → 原子提交 → before/after 截图验证

## 关键差异（vs /plan-design-review）

| | /plan-design-review | /design-review |
|-|--------------------|-----------------------|
| 对象 | 方案（计划阶段） | Live 站点（实现后） |
| 输出 | 更好的方案 | 修复后的代码 |
| 改代码？ | 不改 | 改 |

## DESIGN.md 集成

如果项目有 DESIGN.md，所有设计判断都按它校准。偏离项目设计系统的问题严重度更高。
