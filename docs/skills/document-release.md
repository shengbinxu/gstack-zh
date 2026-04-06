# `/document-release` 技能深度注解

> 对应源文件：[`document-release/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/document-release/SKILL.md.tmpl)
> 发布后文档更新。

---

## 这个技能是什么？

**触发时机**：代码发布后，文档需要同步。

**核心流程**：读所有 .md 文件 → 对比 diff → 更新 README/ARCHITECTURE/CONTRIBUTING/CLAUDE.md → 打磨 CHANGELOG 语气 → 清理 TODOS

**通常不需要手动调用**——`/ship` Step 8.5 自动调用它。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 自动被 /ship 调用 | 零摩擦文档同步 |
| 交叉引用 diff | 只更新需要更新的文档 |
| CHANGELOG 语气 | 面向用户写，不是面向开发者 |
