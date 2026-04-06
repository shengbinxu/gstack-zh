# `/design-html` 技能深度注解

> 对应源文件：[`design-html/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/design-html/SKILL.md.tmpl)
> 设计到生产级 HTML——Pretext 布局引擎。

---

## 这个技能是什么？

**核心**：生成文本真正回流的 HTML。不是 CSS 近似——是计算布局。

**Pretext**：一个微型布局引擎（30KB，零依赖）。文本回流、高度自计算、卡片自适应大小、聊天气泡自收缩、编辑排版绕障碍物流动。

**输入来源**：
- `/design-shotgun` 批准的稿件
- `/plan-ceo-review` 的产品方案
- `/plan-design-review` 的设计规格
- 或用户直接描述

**Smart API Routing**：根据设计类型（landing page / dashboard / blog / form）自动选择正确的 Pretext 模式。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| Pretext 引擎 | 真实布局计算 vs CSS 近似 |
| 30KB 零依赖 | 生产级轻量 |
| Smart API Routing | 按类型选模式 |
| 多输入源 | 和其他技能自然衔接 |
