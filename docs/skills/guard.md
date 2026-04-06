# `/guard` 技能深度注解

> 对应源文件：[`guard/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/guard/SKILL.md.tmpl)
> 最大安全模式——/careful + /freeze 组合。

---

## 这个技能是什么？

同时启用破坏性命令警告（/careful）和目录编辑限制（/freeze）。

**用途**：碰生产环境或调试 live 系统时使用。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 组合技能 | 一条命令最大安全 |
| 碰 prod 时用 | 双重保险 |
