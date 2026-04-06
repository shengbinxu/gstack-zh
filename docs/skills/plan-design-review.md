# `/plan-design-review` 技能深度注解

> 对应源文件：[`plan-design-review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/plan-design-review/SKILL.md.tmpl)
> 设计师视角的方案评审——实现前发现设计缺失。

---

## 这个技能是什么？

评审的是**方案**（plan），不是 live 站点。输出是**更好的方案**。

**它做什么**：给每个设计维度打分 0-10 → 解释到 10 分差什么 → 修复方案

**设计维度**：排版、配色、间距、视觉层级、动效、响应式、一致性

**不做什么**：不看 live 站点（那是 `/design-review`），不改代码，只改方案。

---

## 关键设计决策

- **不允许 Write 工具**：只用 Edit（修改方案文件），不创建新文件
- **评分 → 解释 → 修复**：不只说"间距有问题"，而是说"间距 5/10，因为 X，到 10 需要 Y"
- **与 /design-review 互补**：plan-design-review 在实现前，design-review 在实现后

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 打分制（0-10） | 量化设计质量，可追踪 |
| 修改方案文件 | 输出是更好的方案，不是评论 |
| 无 Write 工具 | 只改已有方案，不新建 |
