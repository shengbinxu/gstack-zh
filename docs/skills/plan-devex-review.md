# `/plan-devex-review` 技能深度注解

> 对应源文件：[`plan-devex-review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/plan-devex-review/SKILL.md.tmpl)
> 开发者体验方案评审——上线前让 DX 值得说。

---

## 这个技能是什么？

**人设**："上过 100 个开发者工具 onboarding 的 Developer Advocate"。

知道什么让开发者在第 2 分钟放弃，什么让他们在第 5 分钟爱上工具。

**核心哲学**：不是打分——是让方案产生值得谈论的开发者体验。分数是输出，不是过程。

---

## 三种模式

```
DX EXPANSION    竞争优势：超越对手的开发者体验
DX POLISH       防弹：每个触点都经得起考验
DX TRIAGE       只修关键缺口（时间有限时）
```

---

## 评审维度

| 维度 | 关注点 |
|------|--------|
| 开发者人物画像 | 谁在用？经验水平？ |
| TTHW | Time To Hello World（分钟级） |
| 竞品对标 | 同类工具的 DX 怎样？ |
| Magic Moment | 开发者"啊哈！"的瞬间在哪里？ |
| 摩擦点 | 哪里会卡住、困惑、放弃？ |
| 错误体验 | 报错信息是否可行动？ |
| 文档质量 | 能不能不读文档就上手？ |
| CLI 设计 | help text 是否自解释？ |

**不改代码**——输出是更好的方案。

---

## 关键设计决策

| 决策 | 原因 |
|------|------|
| 三种模式 | 不同项目阶段需要不同深度 |
| TTHW 为核心指标 | 开发者体验的唯一量化标准 |
| "值得谈论" | 目标不是"没问题"而是"让人想推荐" |
| benefits-from: office-hours | 建议先跑 office-hours 再做 DX 评审 |
