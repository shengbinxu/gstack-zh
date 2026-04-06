# `/plan-ceo-review` 技能深度注解

> 对应源文件：[`plan-ceo-review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/plan-ceo-review/SKILL.md.tmpl)
> CEO/创始人视角评审——重新思考问题，找到 10 星产品。

---

## 这个技能是什么？

`/plan-ceo-review` 让 Claude 用 CEO 视角审视你的技术方案。

**触发时机**：方案定了但想问"够大胆吗？"

**它做什么**：
- 4 种模式：SCOPE EXPANSION（做大）、SELECTIVE EXPANSION（精选扩展）、HOLD SCOPE（只审不扩）、SCOPE REDUCTION（砍到最小）
- 12 个 CEO 认知模式（来自 Bezos、Grove、Horowitz、Munger 等）
- 9 条 Prime Directives（零静默失败、每个错误有名字…）
- 每个范围变更都是 AskUserQuestion——用户 100% 控制

**不做什么**：不写代码，不做实现。

---

## 4 种评审模式

```
SCOPE EXPANSION
  "如果多 2x 工作量能好 10x，做什么？"
  推荐扩展，用户逐个批准

SELECTIVE EXPANSION
  "方案照做，但这几个扩展机会考虑一下"
  中立推荐，用户挑选

HOLD SCOPE
  "方案范围不变，我来找所有隐患"
  最严格的质量审查

SCOPE REDUCTION
  "什么是达到核心目标的最小版本？"
  删掉一切非必需品
```

---

## 12 个 CEO 认知模式

| # | 模式 | 来源 | 核心 |
|---|------|------|------|
| 1 | 分类本能 | Bezos | 可逆×影响大小 → 决策速度 |
| 2 | 偏执扫描 | Grove | 持续扫描战略拐点 |
| 3 | 反转思维 | Munger | 除了"怎么赢"也问"怎么输" |
| 4 | 聚焦即删减 | Jobs | 做更少的事做得更好 |
| 5 | 人优先排序 | Horowitz | 人→产品→利润 |
| 6 | 速度校准 | Bezos | 70% 信息就够决策 |
| 7 | 代理怀疑 | Bezos Day 1 | 指标还在服务用户吗？ |
| 8 | 叙事连贯 | 通用 | 让"为什么"清晰可读 |
| 9 | 时间深度 | Bezos 80岁 | 5-10 年弧度思考 |
| 10 | 创始人模式 | Chesky/Graham | 深度参与≠微管理 |
| 11 | 战时意识 | Horowitz | 和平期习惯在战时致命 |
| 12 | 勇气积累 | 通用 | 信心来自做决定 |

---

## 关键设计原则

### "完整性很便宜"

```
AI coding compresses implementation time 10-100x.
"Ship the shortcut" is legacy thinking.
```

CEO review 的独特视角：在 AI 辅助开发下，做完整版只比做捷径多花几分钟。所以默认推荐完整版。

### 一旦选了模式就不动摇

选了 EXPANSION 就不在后续步骤里偷偷缩范围。选了 REDUCTION 就不偷偷加功能。模式承诺是刚性的。

### 每个范围变更都问

永远不静默加减范围。AskUserQuestion 是唯一的范围变更机制。

---

## 在技能链中的位置

```
/office-hours     （"这值得做吗？"）
      │
      ▼
/plan-ceo-review  ← 你在这里（"怎样做得更大？"）
      │
      ▼
/plan-eng-review  （"怎样做得更稳？"）
```

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 4 种模式 | 不同场景需要不同范围姿态 |
| 12 个认知模式 | CEO 级战略思维 |
| 完整性很便宜 | AI 时代的范围决策新逻辑 |
| 模式承诺刚性 | 防止审查过程中立场漂移 |
| 每次范围变更 AskUser | 用户 100% 控制 |
