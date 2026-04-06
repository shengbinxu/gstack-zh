# `/investigate` 技能深度注解

> 对应源文件：[`investigate/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/investigate/SKILL.md.tmpl)（203 行）
> gstack 的"调试专家"——系统性根因调试。

---

## 这个技能是什么？

`/investigate` 强制 AI 走科学方法：先调查、再分析、再假设、最后修复。

**触发时机**：遇到 bug、500 错误、"昨天还好好的"。

**它做什么**：
- 5 个阶段：根因调查 → 模式分析 → 假设检验 → 实现修复 → 验证报告
- 铁律：没找到根因，不准修
- 3 次假设失败自动停下来
- 自动锁定编辑范围（调用 `/freeze`）

**不做什么**：不猜，不"先试试看"。

---

## Frontmatter 解读

```yaml
---
name: investigate
preamble-tier: 2
hooks:
  PreToolUse:
    - matcher: "Edit"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/../freeze/bin/check-freeze.sh"
    - matcher: "Write"
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/../freeze/bin/check-freeze.sh"
---
```

**hooks**：每次 Edit/Write 时自动运行 `check-freeze.sh`，检查文件是否在允许范围内。防止调试时改不相关代码。

---

## 核心流程图

```
用户说 "这个 bug 怎么回事"
         │
         ▼
┌──────────────────────────────┐
│  Iron Law（铁律）              │
│  "没有根因调查，不准修复"     │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  Phase 1: Root Cause         │
│  ├─ 收集症状（错误/堆栈）    │
│  ├─ 读代码（从症状追溯）     │
│  ├─ 查 git log（回归？）     │
│  ├─ 复现                     │
│  └─ 搜索历史 learnings       │
│  输出：根因假设              │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  Scope Lock（范围锁定）       │
│  识别最窄目录 → freeze       │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  Phase 2: Pattern Analysis   │
│  竞态/空值/状态损坏/集成失败 │
│  /配置漂移/缓存陈旧          │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  Phase 3: Hypothesis Testing │
│  ├─ 加日志/断言验证假设     │
│  ├─ 错误？→ 回 Phase 1     │
│  └─ 3 次失败？→ STOP       │
│      A) 继续  B) 升级  C) 日志│
└──────────────┬───────────────┘
               │ 根因确认
               ▼
┌──────────────────────────────┐
│  Phase 4: Implementation     │
│  ├─ 修根因，不是症状        │
│  ├─ 最小 diff              │
│  ├─ 回归测试（先失败再通过）│
│  └─ >5 文件→ 问爆炸半径   │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  Phase 5: DEBUG REPORT       │
│  Symptom / Root cause /      │
│  Fix / Evidence / Status     │
│  DONE / WITH_CONCERNS /      │
│  BLOCKED                     │
└──────────────────────────────┘
```

---

## 关键设计决策

### Iron Law

AI 的本能是"看到问题就修"。但修症状导致打地鼠：修 A 冒出 B。铁律强制先理解再行动。

### 3-strike rule

3 次假设失败 = 可能是架构问题，不是代码 bug。选项 C（加日志等下次）是务实选择：间歇性 bug 不一定要当场解决。

### Red Flags（AI 自我检测）

- "Quick fix for now" — 没有"先这样"
- 还没追踪数据流就提 fix — 在猜
- 每次修复暴露新问题 — 错误的层

### Scope Lock

调试时自动锁定编辑到最窄目录。与 hooks 配合：每次 Edit/Write 检查范围。物理阻止"顺便改了"。

### Pattern Analysis 表

| 模式 | 特征 | 查找方向 |
|------|------|---------|
| 竞态条件 | 间歇性、时序相关 | 共享状态并发 |
| 空值传播 | TypeError | 缺少守卫 |
| 状态损坏 | 数据不一致 | 事务、回调 |
| 集成失败 | 超时 | 外部 API |
| 配置漂移 | 本地好其他不行 | 环境变量 |
| 缓存陈旧 | 旧数据 | Redis、CDN |

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| Iron Law | 防 AI "先试试" |
| 3-strike | 3 次失败 = 架构问题 |
| Scope Lock | 物理阻止改不相关代码 |
| Pattern Analysis | 结构化排查 |
| 回归测试先失败 | 测试有意义 |
| DEBUG REPORT | 可追溯证据链 |
