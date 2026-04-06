# `/ship` 技能深度注解

> 对应源文件：[`ship/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/ship/SKILL.md.tmpl)（680 行）
> 这是 gstack 最核心的技能之一——全自动发布流程。

---

## 这个技能是什么？

`/ship` 是 gstack 的"发布工程师"。一条命令完成从代码到 PR 的全部流程。

**触发时机**：代码写完了，想推上去。

**它做什么**：
- 合并 base 分支、跑测试、审查 diff
- 版本号自动递增、生成 CHANGELOG
- 拆分 bisectable commits
- 创建 PR（含覆盖率报告、评审结果、eval 结果）
- 自动同步文档（调用 `/document-release`）

**不做什么**：不等你确认。用户说了 `/ship` 就意味着"做吧"。

---

## Frontmatter 解读

```yaml
---
name: ship
preamble-tier: 4       # 最高级别（唯一使用 tier 4 的技能）
sensitive: true         # 涉及 git push，不可逆
allowed-tools:          # 包含 Agent（并行跑测试）
  - Bash, Read, Write, Edit, Grep, Glob, Agent, AskUserQuestion, WebSearch
---
```

**preamble-tier: 4**：唯一使用最高级别的技能，额外包含测试框架检测、失败归因、对抗性评审。

**sensitive: true**：`git push` 不可逆，让宿主 AI 显示额外确认。

---

## 核心流程图

```
/ship
  │
  ▼
┌────────────────────────────────────────┐
│ Step 1: Pre-flight                     │
│ ├─ 在 base 分支？→ 中止               │
│ ├─ git status + diff + log            │
│ └─ 检查评审就绪看板                    │
├────────────────────────────────────────┤
│ Step 1.5: Distribution Pipeline Check  │
│ └─ 新增二进制/包？检查发布管道         │
├────────────────────────────────────────┤
│ Step 2: Merge base branch              │
│ └─ git fetch + merge（冲突则停）       │
├────────────────────────────────────────┤
│ Step 3: Run tests（合并后代码）         │
│ ├─ 并行跑 Rails + Vitest              │
│ ├─ 失败→ 归因（本分支 vs 已有问题）   │
│ └─ 全部通过→ 继续                     │
├────────────────────────────────────────┤
│ Step 3.25: Eval Suites（条件触发）     │
│ └─ diff 涉及 prompt 文件 → 跑 eval   │
├────────────────────────────────────────┤
│ Step 3.4: Test Coverage Audit          │
│ └─ 缺测试的新代码→ 自动生成          │
├────────────────────────────────────────┤
│ Step 3.5: Pre-Landing Review           │
│ ├─ Pass 1: SQL安全 + LLM信任边界      │
│ ├─ Pass 2: 其余类别                   │
│ ├─ AUTO-FIX 直接修                    │
│ └─ ASK → AskUserQuestion              │
├────────────────────────────────────────┤
│ Step 4: Version bump                   │
│ ├─ MICRO/PATCH → 自动                 │
│ └─ MINOR/MAJOR → 问用户              │
├────────────────────────────────────────┤
│ Step 5-5.5: CHANGELOG + TODOS.md      │
├────────────────────────────────────────┤
│ Step 6: Bisectable Commits             │
│ 基础设施→模型→控制器→VERSION+CHANGELOG│
├────────────────────────────────────────┤
│ Step 6.5: Verification Gate            │
│ "自信不是证据" → 重跑测试            │
├────────────────────────────────────────┤
│ Step 7: Push → Step 8: Create PR       │
├────────────────────────────────────────┤
│ Step 8.5: Auto /document-release       │
│ Step 8.75: Persist metrics for /retro  │
└────────────────────────────────────────┘
```

---

## 关键设计决策

### "只在这些情况下停"

`/ship` 的哲学是"自动化一切可以自动化的"。只有需要人类判断的决策才停：merge 冲突、MINOR/MAJOR 版本、评审 ASK 项。MICRO/PATCH 自动选、CHANGELOG 自动写、commit message 自动生成——永远不停。

### 幂等性（Re-run behavior）

修复后再次 `/ship`：验证步骤（测试、覆盖率、评审）每次重跑。操作步骤（版本号、push、PR）是幂等的——VERSION 已 bump 则跳过 bump，已 push 则跳过 push，PR 已存在则更新 body。

### Verification Gate（Step 6.5）

```
- "Should work now" → RUN IT.
- "I'm confident" → Confidence is not evidence.
- "I already tested earlier" → Code changed since then.
```

写给 AI 的"反自欺"规则。修完代码必须重新验证，不接受"应该没问题"。

### Bisectable Commits

提交顺序：基础设施 → 模型/服务 → 控制器/视图 → VERSION+CHANGELOG。依赖单向流动，每个 commit 独立有效，支持 `git bisect`。

### Test Failure Triage

区分本分支引入的失败（阻止发布）和 base 分支已有的失败（记录不阻止）。避免"别人的 bug 阻止我发布"。

### PR Body = 审计证据链

PR body 包含：Summary（变更摘要）、Test Coverage（覆盖率图）、Pre-Landing Review、Design Review、Eval Results、Greptile Review、Plan Completion、TODOS。不只是描述——是完整的质量证据。

---

## 与其他技能的关系

```
/plan-eng-review  ──→  评审看板  ──→  /ship Step 1
/review           ──→  checklist ──→  /ship Step 3.5
/document-release              ←──  /ship Step 8.5（自动调用）
/retro                         ←──  /ship Step 8.75（消费指标）
/land-and-deploy               ←──  /ship 之后（部署）
```

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 全自动，极少停顿 | /ship = "做吧" |
| 幂等重跑 | 验证每次重跑，操作不重复 |
| Verification Gate | 自信不是证据 |
| Bisectable commits | 每个 commit 独立有效 |
| 测试失败归因 | 区分"我的"和"别人的" |
| PR body = 审计链 | 完整的质量证据 |
