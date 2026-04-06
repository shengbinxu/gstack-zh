# `/review` 技能深度注解

> 对应源文件：`review/SKILL.md.tmpl`
> Pre-Landing PR 评审，找测试抓不到的结构性问题。

---

## 这个技能是什么？

`/review` 分析当前分支对基础分支的 diff，查找 SQL 安全、LLM 信任边界违规、条件副作用等结构性问题。

**核心设计哲学：Fix-First。** 不只是报告问题，能自动修的直接修。

---

## 流程

```
/review
  │
  ├─ Step 1: 检查分支（基础分支则退出）
  ├─ Step 2: 读取 checklist.md（评审清单）
  ├─ Step 2.5: Greptile 评审集成（如有）
  ├─ Step 3: 获取 diff
  ├─ Step 4: Critical Pass（核心评审）
  │   ├─ SQL & 数据安全
  │   ├─ 竞态条件 & 并发
  │   ├─ LLM 输出信任边界
  │   ├─ Shell 注入
  │   ├─ Enum & 值完整性
  │   └─ 其他 INFORMATIONAL 类别
  ├─ Step 5: Fix-First 评审
  │   ├─ 5a: 分类（AUTO-FIX / ASK）
  │   ├─ 5b: 自动修复所有 AUTO-FIX
  │   ├─ 5c: 批量询问 ASK 项
  │   └─ 5d: 应用用户批准的修复
  ├─ Step 5.5: TODOS 交叉引用
  ├─ Step 5.6: 文档过期检查
  └─ Step 5.8: 持久化评审结果
```

## Fix-First 启发式

```
每个发现 → 分类：
  AUTO-FIX：机械修复（死代码、N+1、过期注释）→ 直接修
  ASK：需要判断（架构决策、安全选择）→ 批量问用户

[AUTO-FIXED] app/models/post.rb:42 Problem → what you did
[ASK] app/services/auth.rb:88 — 需要你决定
```

## 关键设计决策

| 决策 | 原因 |
|------|------|
| checklist.md 外部化 | 评审清单可独立更新，不绑定技能版本 |
| Enum 完整性需跨 diff 读代码 | 唯一一个"只看 diff 不够"的检查类别 |
| Greptile 集成 | 第三方 AI 评审的意见也要分类处理 |
| 持久化评审结果 | /ship 看板读取历史评审数据 |
| 验证声明规则 | 不允许说"大概处理了"，必须引用具体代码行 |
