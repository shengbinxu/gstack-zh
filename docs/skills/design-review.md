# `/design-review` 技能深度注解

> 对应源文件：[`design-review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/design-review/SKILL.md.tmpl)
> Live 站点视觉 QA + 修复——设计师+前端工程师二合一。

---

## 这个技能是什么？

**preamble-tier: 4**（最高级），因为需要测试框架检测。

**核心流程**：browse 截图 → 发现视觉问题 → 修源码 → 原子提交 → 重新截图验证

**人设**："资深产品设计师 + 前端工程师"——能发现问题，也能修复。

---

## AI Slop 检测

这是 `/design-review` 独有的审查维度：
- 过于均匀的间距（真实设计有节奏变化）
- 缺乏个性的排版（所有标题大小接近）
- "库存照片感"（太完美反而不真实）
- 动效完全缺失或全部一样

---

## 与 /qa 的对比

| | /qa | /design-review |
|--|-----|---------------|
| 关注点 | 功能正确性 | 视觉质量 |
| 修复方式 | 同——原子提交 + 截图 |
| 工具 | browse | browse |
| 代码修改 | 逻辑代码 | CSS/布局代码 |

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| AI Slop 检测 | AI 生成界面的新质量问题 |
| Fix Loop 同 /qa | 原子提交 + before/after |
| preamble-tier 4 | 需要测试框架检测 |
