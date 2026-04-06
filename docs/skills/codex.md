# `/codex` 技能深度注解

> 对应源文件：[`codex/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/codex/SKILL.md.tmpl)
> 多 AI 第二意见——"200 IQ 直男开发者"。

---

## 这个技能是什么？

`/codex` 用 OpenAI Codex CLI 获取独立的第二意见。

**触发时机**：想要不同 AI 系统的看法。

**它做什么**：
- 3 种模式：Review（评审 diff）、Challenge（对抗性）、Consult（问答）
- Review：独立 diff 评审 + pass/fail 判定
- Challenge：试图打破你的代码
- Consult：问 Codex 任何问题，支持会话连续性

**Codex 的人设**："200 IQ autistic developer"——直接、简洁、技术精确、挑战假设。

---

## 3 种模式

```
/codex review     → 评审当前分支 diff
/codex challenge  → 对抗模式，试图找 bug
/codex <question> → 咨询模式，问任何问题
/codex            → 自动检测（有 diff → Review/Challenge）
```

---

## 关键设计决策

### 跨模型共识

当 Claude 和 Codex 在一个发现上达成一致，这是强信号（Cross-model consensus）。但仍然需要用户通过 AskUserQuestion 确认——共识 ≠ 自动采纳。

### Reasoning Effort

```
Review:    high  — 有界输入，需要彻底
Challenge: high  — 对抗但有界
Consult:   medium — 大上下文，需要速度
可用 --xhigh 覆盖
```

### 忠实呈现

Codex 的输出直接呈现，不经 Claude 总结或软化。这是设计意图：
用户要的是不同视角，不是 Claude 重新包装的版本。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 3 种模式 | 评审/对抗/咨询覆盖不同需求 |
| 跨模型共识 | 强信号但仍需用户确认 |
| 忠实呈现 | 不二次包装，保持独立视角 |
| 会话连续 | Consult 支持追问 |
