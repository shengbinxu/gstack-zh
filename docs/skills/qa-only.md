# `/qa-only` 技能深度注解

> 对应源文件：[`qa-only/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/qa-only/SKILL.md.tmpl)
> 只报告不修复的 QA。

---

## 这个技能是什么？

`/qa-only` 是 `/qa` 的"只读版"——发现 bug 但不修复。

---

## vs /qa

| | /qa | /qa-only |
|--|-----|---------|
| 测试 | 是 | 是 |
| 修复 | 是（原子 commit） | **否** |
| 回归测试 | 自动生成 | 否 |
| 健康分数 | before + after | **只有 before** |
| 输出 | 修复 + 报告 | **只有报告** |

**用途**：
- 想要 bug 列表但不想让 AI 自动修
- 需要人工审核修复方案的场景
- 给团队其他成员分配 bug

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 与 /qa 共享测试方法论 | 相同的发现质量 |
| 没有 Fix Loop | 纯报告，用户决定如何修 |
| 独立技能（不是 /qa --no-fix） | 不同的 allowed-tools |
