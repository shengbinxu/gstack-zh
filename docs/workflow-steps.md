# gstack 完整需求开发工作流步骤

适用场景：在已有项目中开发一个包含 web 前端 + 后端的新需求。

---

## 准备工作（一次性）

```bash
# 确认 gstack 已安装且是最新版本
/gstack-upgrade

# 确认项目 CLAUDE.md 已有 skill routing 规则
# （/autoplan 首次运行会自动提示添加）
```

---

## Step 1：需求澄清 `/office-hours`

**什么时候跳过**：需求已完全清晰，直接进 Step 2。

**什么时候必须做**：
- 需求来自外部（产品/客户），细节未确认
- 你不确定"值不值得做"或"做哪个方案"
- 有多个实现思路，想先碰碰

```
/office-hours
```

产出：明确的需求定义、用户 story、关键决策。

---

## Step 2：规划 `/autoplan`

**必须做，不可跳过。**

```
/autoplan
```

`/autoplan` 会引导你完成：

### 2a. 写 CEO Plan

路径：`~/.gstack/projects/$SLUG/ceo-plans/{date}-{feature}.md`

内容：
- 需求背景和用户 story
- 技术方案（前端：组件/页面/路由；后端：API/schema/service）
- 风险和依赖
- 完成标准（Definition of Done）

### 2b. Eng Review（必须通过）

```
/plan-eng-review
```

审查：
- 架构设计是否合理
- 数据库 schema 变更影响
- API 设计（RESTful/命名/版本）
- 测试策略（单元/集成/E2E 各覆盖什么）
- 性能风险（N+1、大查询、缓存需要）

**不通过 eng review 不能进入实现阶段。**

### 2c. CEO Review（有产品决策时推荐）

```
/plan-ceo-review
```

审查：scope 是否合理、用户价值是否清晰、有无过度设计。

### 2d. Design Review（有 UI 时推荐）

```
/plan-design-review
```

审查：交互流程、组件复用、空/错误状态的 UI 处理。

**Step 2 产出**：通过 eng review 的 CEO Plan，Review Dashboard 显示 CLEAR。

---

## Step 3：实现

按 CEO Plan 开发。建议顺序：

### 3a. 后端先行

```
schema 变更（migration）
  ↓
model / 数据层
  ↓
service / 业务逻辑（含单元测试）
  ↓
API routes / controllers（含集成测试）
```

遇到 bug：
```
/investigate
```

每完成一个独立子模块保存进度：
```
/checkpoint
```

### 3b. 前端对接

```
类型定义 / API client
  ↓
组件（含 storybook 或快照测试，如果项目有）
  ↓
页面集成
  ↓
E2E 测试（核心用户流程）
```

遇到 bug：
```
/investigate
```

关键节点保存进度：
```
/checkpoint
```

---

## Step 4：QA `/qa`

```
/qa
```

覆盖：
- 正常路径（happy path）
- 边界条件（空值、最大值、并发）
- 错误状态（网络失败、权限不足、数据异常）
- 回归（已有功能是否受影响）

发现 bug → 修复 → 重新 `/qa`，直到通过。

---

## Step 5：Ship `/ship`

```
/ship
```

自动执行：
1. 检查当前分支（不在 base branch）
2. Merge base branch（先 merge 再测试）
3. 跑完整测试套件
4. Test Failure Ownership Triage（区分自己引入 vs pre-existing）
5. Test Coverage Audit（追踪每个 codepath，补写缺失测试）
6. Pre-landing Review（inline code review）
7. VERSION bump + CHANGELOG 生成
8. Commit + Push
9. 创建 PR（含 10 个 section 的完整 body）

**只有这些情况需要人工介入**：
- 自己引入的测试失败（必须修）
- 复杂 merge conflict
- Coverage 明显不足（会给 override 选项）
- MINOR/MAJOR 版本号判断

---

## Step 6：上线后 `/document-release`

PR merge 后：

```
/document-release
```

更新：API 文档、README、CHANGELOG、任何受影响的内部文档。

---

## 完整流程图

```
[需求模糊？]
    ↓ Yes
/office-hours
    ↓
/autoplan
    ├─ CEO Plan 草稿
    ├─ /plan-eng-review（必须 CLEAR）
    ├─ /plan-ceo-review（推荐）
    └─ /plan-design-review（有 UI 时）
    ↓
实现：后端
    ├─ schema → model → service → routes
    ├─ /investigate（遇 bug）
    └─ /checkpoint（里程碑）
    ↓
实现：前端
    ├─ types → components → 页面 → E2E
    ├─ /investigate（遇 bug）
    └─ /checkpoint（里程碑）
    ↓
/qa
    ↓（通过）
/ship
    ↓（PR merge）
/document-release
```

---

## 常见问题

**Q：必须严格按顺序吗？**
前端和后端可以并行，但 `/autoplan`（含 eng review）必须在写任何代码之前完成。

**Q：一个需求需要多个 feature branch 吗？**
eng review 里会讨论拆分策略。大需求通常拆成多个可独立 ship 的 PR。

**Q：`/checkpoint` 保存什么？**
当前进度、未完成项、遇到的问题、下次继续的切入点。context 丢失后用 `/checkpoint` 恢复。

**Q：`/ship` 失败了怎么办？**
按提示修复具体问题，再次运行 `/ship`（幂等，安全重跑）。
