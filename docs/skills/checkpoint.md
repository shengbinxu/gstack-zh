# `/checkpoint` 技能深度注解

> 对应源文件：[`checkpoint/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/checkpoint/SKILL.md.tmpl)
> 保存/恢复工作状态。

---

## 这个技能是什么？

捕获 git 状态 + 已做决策 + 剩余工作，让你可以精确恢复到离开的地方。

**触发时机**：要切换上下文、长时间休息、或跨分支工作。

**核心价值**：AI 会话是有状态的但会话会结束。Checkpoint 把状态持久化到文件。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| git 状态 + 决策 + TODO | 完整上下文恢复 |
| 跨会话 | 不依赖会话内存 |
