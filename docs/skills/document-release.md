# `/document-release` 技能深度注解

> 对应源文件：`document-release/SKILL.md.tmpl`
> 发布后文档更新：确保文档与代码一致。

## 核心定位

在 /ship 之后、PR 合并之前运行。读取所有文档，与 diff 交叉引用，更新 README/ARCHITECTURE/CONTRIBUTING/CLAUDE.md。

## 自动 vs 手动决策

| 自动做 | 停下来问 |
|--------|---------|
| 从 diff 来的事实更正 | 叙事性/哲学性变更 |
| 添加表格/列表项 | VERSION bump |
| 更新路径、版本号、计数 | 新 TODOS 项 |
| 修复过期交叉引用 | 大范围重写 |
| CHANGELOG 措辞润色 | |
| 标记 TODOS 完成 | |

## NEVER 规则

- 永远不覆盖 CHANGELOG 条目（只润色措辞）
- 永远不自动 bump VERSION
- 永远不用 Write 工具编辑 CHANGELOG（只用 Edit + 精确匹配）
