# `/qa` 技能深度注解

> 对应源文件：[`qa/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/qa/SKILL.md.tmpl)（333 行）
> gstack 的"QA 工程师"——测试、修复、验证一条龙。

---

## 这个技能是什么？

`/qa` 不只是测试——它找到 bug 后还会修复，然后重新验证。

**触发时机**：功能写完了，"能不能用"。

**它做什么**：
- 用真实浏览器（无头 Chromium）系统性测试
- 发现 bug → 定位源码 → 最小修复 → 原子提交 → 重新验证
- 每个修复一个 commit，回归则自动 revert
- Before/after 截图 + 健康分数
- 三层级：Quick / Standard / Exhaustive

**不做什么**：不改 CI 配置，不改已有测试，不重构。

---

## 核心流程图

```
/qa https://myapp.com
         │
         ▼
┌──────────────────────────────────┐
│  Setup                           │
│  ├─ 参数（URL/Tier/Mode）       │
│  ├─ CDP 模式？（真实浏览器）    │
│  ├─ 工作区干净？               │
│  │   └─ 不干净→ Commit/Stash?  │
│  └─ 找 browse 二进制 + 输出目录│
├──────────────────────────────────┤
│  Phase 1-6: QA Baseline          │
│  └─ browse 系统测试 → 基线分数 │
├──────────────────────────────────┤
│  Phase 7: Triage                 │
│  ├─ Quick:  critical + high      │
│  ├─ Standard: + medium          │
│  └─ Exhaustive: + cosmetic      │
├──────────────────────────────────┤
│  Phase 8: Fix Loop（核心循环）   │
│  ┌─────────────────────────┐    │
│  │ 8a. Locate source       │    │
│  │ 8b. Fix（最小修复）     │    │
│  │ 8c. Commit（原子提交）  │    │
│  │ 8d. Re-test + 截图      │    │
│  │ 8e. Classify             │    │
│  │ 8e.5. Regression Test   │    │
│  │ 8f. WTF > 20%? → STOP  │    │
│  └─────────────────────────┘    │
│  硬上限: 50 个修复              │
├──────────────────────────────────┤
│  Phase 9: Final QA               │
│  └─ 最终分数 < 基线？→ WARN   │
├──────────────────────────────────┤
│  Phase 10: Report                │
│  └─ .gstack/qa-reports/         │
├──────────────────────────────────┤
│  Phase 11: TODOS.md              │
│  └─ deferred bug → TODO        │
└──────────────────────────────────┘
```

---

## 关键设计决策

### 原子 Commit（一 bug 一提交）

```
git commit -m "fix(qa): ISSUE-NNN — short description"
One commit per fix. Never bundle.
```

回归时精确 revert 一个 commit。PR 评审逐个查看。`git bisect` 定位。

### WTF-Likelihood 自我调节

```
Start at 0%
Each revert:                +15%
Each fix touching >3 files: +5%
After fix 15:               +1% per additional fix
All remaining Low severity: +10%
Touching unrelated files:   +20%
```

AI 的"我是不是在越帮越忙"量化指标。WTF > 20% 立即停。硬上限 50 修复。

### Clean Working Tree

QA 前要求无未提交变更。每个修复需独立 commit，混了用户代码无法区分。

### Diff-aware 模式

没给 URL + feature 分支 → 只测当前分支改过的功能。最常见场景零配置。

### 回归测试生成

每个成功修复自动生成回归测试：
1. 研究项目已有测试模式
2. 追踪 bug 代码路径
3. 测试必须在没修复时失败（证明有意义）
4. 通过→提交；失败→删除

---

## 输出结构

```
.gstack/qa-reports/
├── qa-report-myapp-com-2026-03-12.md
├── screenshots/
│   ├── initial.png
│   ├── issue-001-before.png
│   ├── issue-001-after.png
│   └── ...
└── baseline.json
```

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 原子 commit | 精确 revert + clean bisect |
| WTF 自我调节 | 防止越帮越忙 |
| Clean tree | 分离用户代码和 QA 修复 |
| 回归测试先失败 | 证明测试有意义 |
| Before/after 截图 | 可视化修复证据 |
| 硬上限 50 | 防止无限循环 |
