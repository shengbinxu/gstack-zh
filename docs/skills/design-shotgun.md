# `/design-shotgun` 技能深度注解

> 对应源文件：[`design-shotgun/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/design-shotgun/SKILL.md.tmpl)
> 视觉设计探索——生成多个方向，并排比较。

---

## 这个技能是什么？

**触发时机**：想看"可能长什么样"。

**核心流程**：用 GPT Image API 生成多个设计方向 → 浏览器打开比较板 → 收集反馈 → 迭代

**为什么叫 Shotgun？** 散弹枪式探索——同时射出多个方向，看哪个命中。

---

## 关键设计决策

- **有 Agent 工具**：并行生成多个变体
- **纯视觉头脑风暴**：不写代码，只生成图和比较
- **会话持久化**：approved.json 保存选定方向，下次可以继续
- **接 /design-html**：选定方向后可直接转为生产代码

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 并行生成 | Agent 工具让多个变体同时生成 |
| 比较板 | 并排看比单独看更容易选 |
| 持久化 | approved.json 跨会话保存 |
