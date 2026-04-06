# `/office-hours` 技能深度注解

> 对应源文件：[`office-hours/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/office-hours/SKILL.md.tmpl)（约 500 行）
> 整个技能链的起点——YC 产品诊断。

---

## 这个技能是什么？

`/office-hours` 模拟 YC（Y Combinator）合伙人的产品诊断会议。

**触发时机**：有个新想法，不确定值不值得做。

**它做什么**：
- 两种模式：Startup（创业诊断）和 Builder（构建者头脑风暴）
- Startup 模式：6 个逼问（需求真实性、现状竞争、绝望具体性…）
- Builder 模式：设计思维协作（更友好，但同样严格）
- 输出设计文档（保存到 `~/.gstack/projects/`）
- 包含对抗性评审（评分 + 修订循环）

**不做什么**：不写代码。这是一个纯策略技能——输出是文档，不是实现。

---

## Frontmatter 解读

```yaml
---
name: office-hours
preamble-tier: 3
allowed-tools:
  - Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion, WebSearch
---
```

**为什么没有 Agent？** Office hours 是对话式的，需要人类在循环中。不适合并行。

**HARD GATE**：模板明确禁止调用任何实现技能或写代码。唯一输出是设计文档。

---

## 核心流程图

```
/office-hours "我有个想法..."
         │
         ▼
┌──────────────────────────────────┐
│  Phase 1: Context Gathering      │
│  ├─ 读 CLAUDE.md/TODOS.md      │
│  ├─ git log 近期上下文          │
│  ├─ 查已有设计文档              │
│  └─ AskUserQuestion: 你的目标？ │
│     ├─ Startup/内部创业 → 2A   │
│     └─ Hackathon/开源/学习 → 2B│
├──────────────────────────────────┤
│  Phase 2A: Startup 诊断          │
│  6 个逼问：                      │
│  1. 需求证据（不是兴趣）        │
│  2. 现状/现有替代方案           │
│  3. 绝望具体性（具体到姓名）    │
│  4. 最窄楔子（最小可付费版）    │
│  5. 第一手观察（看用户用）      │
│  6. 未来适应性                   │
│  ──────────────────────         │
│  Phase 2B: Builder 头脑风暴      │
│  前提假设挑战 + 竞品分析         │
│  + 方案设计                      │
├──────────────────────────────────┤
│  Phase 3: Landscape Research     │
│  ├─ WebSearch 竞品               │
│  └─ 已有开源方案？              │
├──────────────────────────────────┤
│  Phase 4: Alternatives           │
│  ├─ 3 个方案（含"不做"选项）    │
│  └─ AskUserQuestion 选方案      │
├──────────────────────────────────┤
│  Phase 5: Design Doc             │
│  ├─ 写设计文档                   │
│  ├─ 对抗性评审（打分 → 修订）   │
│  └─ AskUserQuestion: 批准？     │
├──────────────────────────────────┤
│  Phase 6: Closing                │
│  ├─ 保存文档到 ~/.gstack/       │
│  └─ 建议下一步                   │
│     /plan-ceo-review 或          │
│     /plan-eng-review             │
└──────────────────────────────────┘
```

---

## 关键设计决策

### Anti-Sycophancy Rules（反谄媚规则）

```
Never say during diagnostic:
- "That's an interesting approach" → take a position
- "There are many ways" → pick one
- "You might want to consider..." → "This is wrong because..."
- "That could work" → say whether it WILL work
```

AI 的默认模式是"都挺好的"。Office hours 显式禁止这些客气话——
因为产品诊断的价值就在于不舒服的诚实。

### Startup 模式的 6 个逼问

1. **需求证据**：不是"有人感兴趣"，是"有人付钱/有人在你宕机时打电话"
2. **现状竞争对手**：真正的竞争对手不是其他创业公司，是"Excel + Slack 凑合"
3. **绝望具体性**：具体到一个人名、一个公司、一个原因
4. **最窄楔子**：本周有人会为此付钱的最小版本
5. **第一手观察**：坐在用户背后看他挣扎（不是引导演示）
6. **未来适应性**：5-10 年这个问题还存在吗？

### Builder 模式

比 Startup 模式更友好，但同样严格：
- 仍然挑战前提假设
- 仍然做竞品研究
- 但语气从"诊断"变为"协作"

### 对抗性评审

设计文档写完后会自我评审（打分 1-10），
识别弱点并修订，直到达到可接受的质量。

---

## 在技能链中的位置

```
/office-hours  ← 你在这里（"这值得做吗？"）
      │
      ▼
/plan-ceo-review  （"怎样做得更大？"）
      │
      ▼
/plan-eng-review  （"怎样做得更稳？"）
      │
      ▼
/ship             （"发出去"）
```

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 反谄媚规则 | 诊断价值在于诚实，不在于客气 |
| 6 个逼问 | 从 YC 提炼的产品验证框架 |
| HARD GATE 不写代码 | 先想清楚再动手 |
| 对抗性评审 | 设计文档自我挑战 |
| 保存到 ~/.gstack/ | 跨会话持久化 |
| 两种模式 | 创业严格诊断 vs 构建者协作 |
