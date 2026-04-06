# `/document-release` 技能深度注解

> 对应源文件：[`document-release/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/document-release/SKILL.md.tmpl)
> 发布后文档同步——零摩擦让文档跟上代码。

---

## 这个技能是什么？

**触发时机**：代码发布后。通常由 `/ship` Step 8.5 自动调用。

**它做什么**：
- 读所有 .md 文件 → 对比 diff → 自动更新
- README: 新功能描述、API 端点、命令列表
- ARCHITECTURE: 新组件、新流程
- CONTRIBUTING: 新的开发步骤
- CLAUDE.md: 新配置、新命令
- CHANGELOG: 打磨语气（面向用户写）
- TODOS: 标记完成项

---

## "只停 / 永不停" 规则

**只在这些情况停**：
- 有风险的文档修改（叙事、哲学、安全、大重写）
- VERSION bump 决策
- 新 TODOS 项
- 跨文档叙事矛盾

**永远不停**：
- 来自 diff 的事实更正
- 添加到表格/列表
- 更新路径、数字、版本号
- 修复过时的交叉引用
- CHANGELOG 语气微调
- 标记 TODOS 完成

**永远不做**：
- 覆盖/替换 CHANGELOG 条目——只打磨措辞
- 不问就 bump VERSION
- 不用 Write 工具改 CHANGELOG——只用 Edit

---

## 关键设计决策

| 决策 | 原因 |
|------|------|
| 被 /ship 自动调用 | 零摩擦，用户不需要记住更新文档 |
| Edit 不 Write CHANGELOG | 防止意外覆盖整个文件 |
| 交叉引用 diff | 只更新需要更新的，不瞎改 |
| CHANGELOG 语气 | 面向用户，不是面向开发者 |
