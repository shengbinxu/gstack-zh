# `/ship` 技能深度注解

> 对应源文件：[`ship/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/ship/SKILL.md.tmpl)
> gstack 的"发布工程师"，从代码到 PR 一条龙。

---

## 这个技能是什么？

`/ship` 是完全自动化的发布流程：合并基础分支 → 运行测试 → 代码评审 → 版本号 → CHANGELOG → 提交 → 推送 → 创建 PR。

**核心设计哲学：非交互式。** 用户说 `/ship` 就意味着"做它"，不要问确认。

---

## 流程（8+ 步骤）

```
/ship
  │
  ├─ Step 1: Pre-flight（检查分支、review 看板）
  ├─ Step 1.5: 分发管道检查（新二进制有没有 CI/CD？）
  ├─ Step 2: 合并基础分支（测试前合并，确保测试跑合并后的代码）
  ├─ Step 2.5: 测试框架引导
  ├─ Step 3: 运行测试（并行跑测试套件）
  ├─ Step 3.25: Eval 套件（如果改了 prompt 文件）
  ├─ Step 3.4: 测试覆盖率审计
  ├─ Step 3.45: 计划完成度审计
  ├─ Step 3.5: Pre-Landing Review（内置代码评审）
  ├─ Step 4: VERSION + CHANGELOG
  ├─ Step 5: TODOS.md 更新
  ├─ Step 6: 提交（bisect commits）
  ├─ Step 7: 推送
  └─ Step 8: 创建 PR
```

## 什么时候会停下来？

| 会停 | 不会停 |
|------|-------|
| 在基础分支上（中止） | 未提交的变更（直接包含） |
| 合并冲突 | 版本号选择（自动 MICRO/PATCH） |
| 测试失败 | CHANGELOG 内容（自动生成） |
| 需要 MINOR/MAJOR 版本号 | 提交消息（自动提交） |
| 覆盖率低于阈值 | 多文件变更（自动拆分 bisect commits） |

## 幂等性设计

```
Re-run /ship = 从头跑一遍所有验证步骤
只有 actions 是幂等的：
  - VERSION 已 bump → 跳过 bump
  - 已推送 → 跳过 push
  - PR 已存在 → 更新 body
验证步骤永远重新跑。
```

## 关键设计决策

| 决策 | 原因 |
|------|------|
| 先合并基础分支再测试 | 测试跑在合并后状态，不是过时代码 |
| bisect commits | 每个 commit 是独立逻辑变更，方便 revert |
| 内置 Pre-Landing Review | 不依赖先前评审，自包含安全网 |
| 分发管道检查 | 代码不能部署 = 代码没人能用 |
| Review Dashboard | 集成评审看板，显示各评审状态 |
