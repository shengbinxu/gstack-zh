# `/design-html` 技能深度注解

> 对应源文件：[`design-html/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/design-html/SKILL.md.tmpl)
> 把设计变成生产级 HTML/CSS（Pretext 原生）。

## 核心定位

生成文本真正能重排的 HTML。不是 CSS 近似，而是通过 Pretext 计算布局。文本在调整大小时重排，高度根据内容调整，卡片自动调整大小。30KB 开销，零依赖。

## 输入来源（自动检测）

1. /design-shotgun 的 approved mockup
2. /plan-ceo-review 的 CEO 计划
3. /plan-design-review 的设计评审上下文
4. 用户直接描述

## 关键特点

- 文本真正重排（不是固定宽度）
- 高度随内容计算
- 卡片自动调整大小
- 零外部依赖（30KB）
