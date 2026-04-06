# `/freeze` 技能深度注解

> 对应源文件：[`freeze/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/freeze/SKILL.md.tmpl)
> 限制文件编辑到指定目录。

---

## 这个技能是什么？

指定一个目录，阻止 AI 编辑该目录之外的文件。

**触发时机**：调试时防止改不相关代码、或只想修改一个模块。

---

## 实现机制

```
/freeze src/auth/
     │
     ▼
写入 ~/.gstack/freeze-dir.txt: "src/auth/"
     │
     ▼
每次 Edit/Write 前，PreToolUse hook 运行 check-freeze.sh：
  目标文件在 src/auth/ 内？→ 允许
  目标文件在 src/auth/ 外？→ 阻止
```

**物理阻止**，不是靠 prompt 自律。hook 在 AI 尝试编辑时自动运行。

---

## 与其他技能的关系

- `/investigate` 自动调用 `/freeze`（锁定调试范围）
- `/guard` = `/careful` + `/freeze` 组合
- `/unfreeze` 解除限制

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| hook 实现 | 物理阻止 > prompt 自律 |
| 最窄目录 | 范围越小越安全 |
| 被 /investigate 自动调用 | 调试范围控制 |
