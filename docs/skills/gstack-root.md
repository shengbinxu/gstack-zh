# gstack 根技能深度注解

> 对应源文件：[`SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/SKILL.md.tmpl)
> 技能路由入口。

---

## 这个技能是什么？

根级 SKILL.md 是 gstack 的路由入口——当用户输入不匹配特定技能时，这个文件提供 browse 工具的通用能力。

**主要内容**：browse 命令列表、snapshot flag 文档、通用浏览器操作指南。

---

## 为什么单独存在？

Claude Code 的技能发现机制按目录扫描。根级 SKILL.md 确保即使用户不知道具体技能名称，也能获得 browse 能力。
