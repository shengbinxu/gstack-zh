# `/qa-only` 技能深度注解

> 对应源文件：[`qa-only/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/qa-only/SKILL.md.tmpl)
> 只报告不修复的 QA。

---

## vs /qa

| | /qa | /qa-only |
|--|-----|---------|
| 测试 | 是 | 是 |
| 修复 | 是 | **否** |
| 输出 | 修复 + 报告 | **只有报告** |

**用途**：想要 bug 列表但不想让 AI 自动修。适合需要人工审核修复方案的场景。
