# `/learn` 技能深度注解

> 对应源文件：[`learn/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/learn/SKILL.md.tmpl)
> 管理项目学习记录——跨会话的知识库。

---

## 这个技能是什么？

**人设**："维护团队 wiki 的 Staff 工程师"。

**HARD GATE**：不改代码，只管理 learnings。

---

## 6 个命令

```
/learn              显示最近 20 条（按类型分组）
/learn search <q>   搜索学习记录
/learn prune        清理过时/矛盾的记录
/learn export       导出到文件
/learn stats        统计：总数、按类型、按项目
/learn add          手动添加一条学习记录
```

---

## 什么是 Learnings？

gstack 在每次技能执行后会自动保存"学到的东西"到 `~/.gstack/learnings/`：

```
~/.gstack/learnings/
├── project-a/
│   ├── learning-2026-04-01-auth-bug.md
│   ├── learning-2026-04-03-perf-pattern.md
│   └── ...
└── project-b/
    └── ...
```

每条记录包含：
- 学到了什么（规律性经验）
- 在什么上下文中发现的
- 建议的应用场景

`/learn` 技能让你管理这些积累的知识。

---

## 关键设计决策

| 决策 | 原因 |
|------|------|
| HARD GATE 不改代码 | 纯知识管理 |
| Prune 功能 | learnings 会随时间变旧 |
| 按项目组织 | 不同项目的经验不混 |
| 自动保存 + 手动管理 | 积累自动，清理手动 |
