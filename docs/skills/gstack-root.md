# gstack 根技能深度注解

> 对应源文件：[`SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/SKILL.md.tmpl)
> 技能路由入口——当没有特定技能匹配时的通用能力。

---

## 为什么有根级 SKILL.md？

Claude Code 按目录扫描技能。根级 SKILL.md 确保：
1. 即使用户不知道具体技能名称，也能使用 browse 能力
2. 通用的 `$B` 命令参考在这里
3. 作为 gstack 的"默认入口"

---

## 内容

主要是 browse 命令的完整参考：
- 所有 65 个命令的简要说明
- Snapshot flag 文档（-i, -D, -a, -c 等）
- 通用 QA 模式
- @ref 系统解释

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 根级存在 | 默认入口，兜底能力 |
| 以 browse 为主 | 浏览器是最通用的工具 |
