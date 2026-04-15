# `/ship` 工作流深度解读

> 对应源码：[`ship/SKILL.md`](https://github.com/garrytan/gstack/blob/main/ship/SKILL.md)（2543 行）
> 本文解读 gstack 最复杂的 skill：/ship 的完整流程、每个 gate 的设计意图、以及核心机制的实现方式。

---

## 1. 两个核心设计原则

### 原则一：全自动，只在必须时停

`/ship` 明确声明"非交互式，全自动"工作流。文档里列出了两张清单：

**只在这些情况 STOP（需要人工判断）：**
- 在 base branch 上（abort）
- 无法自动解决的 merge conflict
- **自己引入的**测试失败（pre-existing 失败有专门处理逻辑）
- Eval suite 失败（prompt 相关文件变更时）
- 需要 MINOR 或 MAJOR 版本号 bump（auto-pick PATCH/MICRO，但 MINOR/MAJOR 太大要问）
- Greptile review 发现需要人工决策的问题
- Coverage 低于最低阈值（有 override 选项）
- Plan 有 NOT DONE 条目（有 override 选项）

**永远不停（全自动处理）：**
- Uncommitted changes（自动包含）
- CHANGELOG 内容（自动从 diff 生成）
- Commit message（自动写）
- Multi-file changesets（自动拆分为可 bisect 的 commits）
- TODOS.md 已完成项（自动 mark）
- Auto-fixable review 发现（dead code、N+1、stale 注释——直接修）

### 原则二：幂等

重跑 `/ship` 等于"重新过一遍所有 checklist"。每个验证步骤（tests、coverage、plan、review、CHANGELOG）每次调用都重新执行。只有**动作**是幂等的：
- VERSION 已 bump → 跳过 bump，但读取当前版本
- 已 push → 跳过 push 命令
- PR 已存在 → 更新 body，不新建

---

## 2. 完整步骤图

```
Step 0    平台检测（GitHub/GitLab/unknown）
          └─ base branch 检测（gh pr view / gh repo view / git symbolic-ref 三重 fallback）
  ↓
Step 1    Pre-flight
          ├─ 在 base branch? → ABORT
          ├─ git status / diff stat / log（了解待 ship 的内容）
          └─ Review Readiness Dashboard
               ├─ 读 ~/.gstack/projects/$SLUG/{branch}-reviews.jsonl
               ├─ Eng Review CLEAR（必须，7天内）→ 继续
               ├─ Eng Review 缺失 → 提示 "ship 会在 Step 3.5 自己跑 review"
               └─ CEO/Design/Adversarial Review → 仅展示，不 block
  ↓
Step 1.5  Distribution Pipeline Check（条件）
          └─ diff 新增 binary/CLI 且无 CI release workflow → AskUserQuestion
  ↓
Step 2    Merge base branch（先 merge 再测试！）
          └─ git fetch origin <base> && git merge origin/<base> --no-edit
          └─ 简单冲突自动解决（VERSION/CHANGELOG 排序），复杂冲突 STOP
  ↓
Step 2.5  Test Framework Bootstrap（条件）
          └─ 仅当没有检测到测试框架时触发
          ├─ B1-B3: 检测运行时 → AskUserQuestion 选框架
          ├─ B4: 安装配置，B4.5: 写 3-5 个真实测试
          ├─ B5: 验证，B5.5: 创建 GitHub Actions CI
          ├─ B6: 写 TESTING.md，B7: 更新 CLAUDE.md
          └─ B8: commit
  ↓
Step 3    跑测试（合并后代码）
          └─ Test Failure Ownership Triage（见下方详解）
  ↓
Step 3.25 Eval Suites（条件）
          └─ 仅当 diff 包含 prompt 相关文件（*_prompt_builder.rb 等）
          └─ EVAL_JUDGE_TIER=full，失败 → STOP
  ↓
Step 3.4  Test Coverage Audit
          ├─ 读 diff，trace 所有 codepath
          ├─ 画 ASCII 分支图（每个 if/else/error path/用户流）
          ├─ 对照现有测试找缺口
          └─ 补写测试，低于阈值时 AskUserQuestion
  ↓
Step 3.45 Plan Completion Audit（条件，有 plan 文件时）
          └─ NOT DONE 条目 → AskUserQuestion
  ↓
Step 3.47 Plan Verification
Step 3.48 Scope Drift Check（读 TODOS.md，对比 plan）
  ↓
Step 3.5  Pre-Landing Review（内联运行 review skill 的 diff 模式）
          └─ ASK 级别 finding → AskUserQuestion
          └─ Auto-fixable finding → 直接修，不问
  ↓
Step 4    VERSION bump + CHANGELOG 更新
          └─ patch/micro 自动选，minor/major 停问
  ↓
Step 5    TODOS.md 处理（已完成项自动 mark）
  ↓
Step 6    Commit（拆分为可 bisect 的多个 commits）
  ↓
Step 7    Push
  ↓
Step 8    PR 创建/更新（见下方 PR body 结构）
  ↓
Telemetry 记录 duration + outcome 到 skill-usage.jsonl（后台异步）
```

---

## 3. Test Failure Ownership Triage（核心机制）

这是 /ship 最有价值的设计，解决了"pre-existing 测试失败阻塞 ship"的痛点。

### 传统做法

测试失败 → 停下 → 开发者手动判断是不是自己引入的，查 git log，看错误信息。

### gstack 做法

```
Step T1: 对每个失败的测试，判断 ownership
         ├─ 获取当前分支变更文件：git diff origin/<base>...HEAD --name-only
         ├─ in-branch：测试文件本身被改动，OR 被测代码在 diff 里，OR 可追溯到分支变更
         ├─ pre-existing：测试文件和被测代码都不在 diff 里
         └─ 不确定时：默认 in-branch（宁可多停，不能漏掉自己的问题）

Step T2: in-branch 失败 → STOP（你的问题，修了再来）

Step T3: pre-existing 失败 → AskUserQuestion
         solo repo:
           A) 现在修（推荐，AI 修比人快，context 最热）
           B) 加入 TODOS.md P0
           C) 跳过（知道了，继续 ship）

         collaborative repo:
           A) 现在修
           B) 找责任人 + 创建 GitHub issue 分配给他
              （git log -1 -- <failing-test-file> 找最后改动者）
           C) 加入 TODOS.md P0
           D) 跳过
```

**设计意图**：pre-existing 失败在 solo repo 不应该让你"直接跳过"（虽然可以选 C），而是推荐你修（AI 修很快），因为这是技术债，越拖越重。在 collaborative repo 则不要越俎代庖，找到责任人分配 issue 是正确做法。

---

## 4. Review Readiness Dashboard

### 数据来源

Step 1 不会现跑 review，而是读缓存：

```bash
~/.claude/skills/gstack/bin/gstack-review-read
# 读 ~/.gstack/projects/$SLUG/{branch}-reviews.jsonl
```

每种 review skill 跑完后写入这个 JSONL。/ship 汇总展示：

```
+====================================================================+
|                    REVIEW READINESS DASHBOARD                       |
+====================================================================+
| Review          | Runs | Last Run            | Status    | Required |
|-----------------|------|---------------------|-----------|----------|
| Eng Review      |  1   | 2026-04-14 15:00    | CLEAR     | YES      |
| CEO Review      |  0   | —                   | —         | no       |
| Design Review   |  0   | —                   | —         | no       |
| Adversarial     |  0   | —                   | —         | no       |
| Outside Voice   |  0   | —                   | —         | no       |
+--------------------------------------------------------------------+
| VERDICT: CLEARED — Eng Review passed                                |
+====================================================================+
```

### Review 分级

| Review | 是否 gate ship | 说明 |
|--------|--------------|------|
| Eng Review | **是**（默认） | 架构、代码质量、测试，7天内有效 |
| CEO Review | 否 | 推荐用于大型产品/业务变更 |
| Design Review | 否 | 推荐用于 UI/UX 变更 |
| Adversarial | 否（总是跑） | diff review 时自动运行，大 diff 额外 Codex 结构化 review |
| Outside Voice | 否 | 不同模型的独立意见 |

**Staleness 检测**：review 记录有 `commit` 字段，/ship 比较 HEAD vs 记录时的 commit，不一致则显示 "N commits since review" 警告。

---

## 5. PR Body 结构

Step 8 创建的 PR body 包含 10 个 section：

```markdown
## Summary
[AI 生成的变更摘要]

## Test Coverage
[Step 3.4 的 coverage audit 结果，before/after 测试数量]

## Pre-Landing Review
[Step 3.5 的 review 结果，CLEAR 或 findings 列表]

## Design Review
[design-review-lite 结果（如果有前端变更）]

## Eval Results
[Step 3.25 的 eval 结果和成本（如果跑了 eval）]

## Greptile Review
[Greptile 扫描结果（如果配置了）]

## Scope Drift
[Step 3.48 的 scope drift 分析]

## Plan Completion
[Step 3.45 的 plan 完成状态]

## Verification Results
[Step 3.47 的验证脚本结果]

## TODOS
[未完成项列表（如果有）]
```

---

## 6. 关键实现细节

### /ship 是 markdown，不是代码

整个 /ship 工作流是一个 2543 行的 markdown 文件。没有 Go/Python/Node 运行时。Claude 读这个 markdown，然后按照里面的指令调用 Bash/Read/Edit/Write 工具。

"框架"就是 Claude 的推理能力，加上结构化的 markdown 指令。

### Step 2 必须在 Step 3 之前

先 merge base branch，**再跑测试**。测试在合并后的代码上运行，发现的失败才是真实的失败。很多项目犯的错是：在 feature branch 上测试通过了，merge 后才发现冲突导致的问题。

### Coverage Audit 画 ASCII 分支图

Step 3.4 要求 Claude 对每个 changed file：

1. 追踪数据流（entry point → branches → error paths）
2. 画 ASCII 分支图，标记每个 if/else/catch/用户流
3. 对照现有测试，每个分支找对应的测试

这不是"跑 coverage 工具看报告"，而是**语义级别的 coverage 分析**：Claude 理解代码意图，再判断哪些路径缺测试。
