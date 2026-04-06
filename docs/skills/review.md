# `/review` 技能深度注解

> 对应源文件：[`review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/review/SKILL.md.tmpl)
> Pre-Landing PR 评审——代码合并前的最后一道关。

---

## 这个技能是什么？

`/review` 是独立的代码评审技能，分析 diff 中测试无法捕捉的结构性问题。

**触发时机**：代码要合并前。

**它做什么**：
- 读取 `review/checklist.md`（结构化评审清单）
- 两轮扫描：Critical（SQL安全、LLM信任边界）→ Informational（其余）
- 专项评审军团（安全、测试、性能、API 等）
- Auto-fix 可自动修的问题，ASK 需要判断的
- 置信度校准（防止过度/不足报告）
- Greptile 机器人评论的分类和回复

**不做什么**：不 push，不创建 PR。只评审。

---

## 核心流程图

```
/review
  │
  ▼
┌────────────────────────────┐
│ Step 1: Check branch       │
│ └─ 在 base 分支？→ 停    │
├────────────────────────────┤
│ Scope Drift Check          │
│ └─ 变更是否超出计划范围？ │
├────────────────────────────┤
│ Plan Completion Audit      │
│ └─ 计划中项目是否完成？   │
├────────────────────────────┤
│ Step 2: Read checklist     │
│ └─ review/checklist.md    │
├────────────────────────────┤
│ Step 2.5: Greptile         │
│ └─ 获取 PR 上的评论       │
├────────────────────────────┤
│ Step 3: Get diff           │
│ └─ git diff origin/<base> │
├────────────────────────────┤
│ Step 4: Critical pass      │
│ ├─ SQL & Data Safety       │
│ ├─ Race Conditions         │
│ ├─ LLM Trust Boundary     │
│ ├─ Shell Injection         │
│ └─ Enum Completeness      │
├────────────────────────────┤
│ Step 5: Informational pass │
│ + Specialist Review Army   │
│ + Design Review Lite       │
├────────────────────────────┤
│ Step 6: Fix-First flow     │
│ ├─ AUTO-FIX → 直接修     │
│ └─ ASK → AskUserQuestion │
├────────────────────────────┤
│ Step 7: Adversarial Review │
│ └─ 用 Codex 二次审查     │
├────────────────────────────┤
│ Step 8: Review Log         │
│ └─ ~/.gstack/reviews/     │
│    供 /ship 看板使用       │
└────────────────────────────┘
```

---

## 关键设计决策

### 两轮扫描

Critical pass 优先看最危险的类别（SQL 注入、LLM 输出信任）。
如果这里有问题，可能需要立即修复。Informational pass 处理风格、性能等。

### Fix-First Heuristic

不是"列出问题让用户自己修"，而是能自动修的直接修。
只有需要判断的问题才 AskUserQuestion。节省 90% 的评审往返。

### Review Army（专项评审军团）

根据 diff 涉及的范围，动态派遣专项审查者：
- 安全变更？→ 安全专项
- 新 API？→ API 设计专项
- 性能敏感？→ 性能专项
- 前端变更？→ Design Review Lite

### 置信度校准

每个发现标注置信度（高/中/低），防止"为了完整性"列出大量低置信度问题。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| Critical → Informational 两轮 | 最危险的先看 |
| Fix-First | 能修的直接修，减少往返 |
| Review Army | 按 diff 动态派遣专项 |
| Greptile 集成 | 利用第三方评审机器人 |
| Review Log | 供 /ship 评审看板使用 |
