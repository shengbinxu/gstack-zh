# `/freeze` 技能深度注解

> 对应源文件：[`freeze/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/freeze/SKILL.md.tmpl)
> 限制文件编辑范围。

---

## 这个技能是什么？

指定一个目录，阻止 Edit/Write 到该目录之外。

**用途**：调试时防止改到不相关代码。`/investigate` 自动调用它。

**解除**：运行 `/unfreeze`。

---

## 实现机制

写入 `~/.gstack/freeze-dir.txt`，PreToolUse hook 在每次 Edit/Write 前检查。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| hook 实现 | 物理阻止，不靠 prompt 自律 |
| 被 /investigate 调用 | 调试范围控制 |
