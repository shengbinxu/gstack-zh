# `/qa` 技能深度注解

> 对应源文件：`qa/SKILL.md.tmpl`
> 用真实浏览器系统性测试，发现 bug 后直接修复。

## 核心定位

`/qa` = QA 工程师 + Bug 修复工程师。用无头浏览器像真实用户一样测试，发现 bug 后在源码里修复，原子提交，再验证。

## 三个级别

| 级别 | 修复范围 | 场景 |
|------|---------|------|
| Quick | 仅 critical + high | 快速烟雾测试 |
| Standard（默认） | + medium | 日常 QA |
| Exhaustive | + low/cosmetic | 发布前全面检查 |

## 流程：Test → Fix → Verify 循环

```
Phase 1-6: QA 基线（发现问题，记录 health score）
Phase 7: 分级（按严重度排序，决定修哪些）
Phase 8: 修复循环
  ├─ 8a: 定位源码
  ├─ 8b: 最小修复
  ├─ 8c: 原子提交（fix(qa): ISSUE-NNN）
  ├─ 8d: 重新测试（before/after 截图）
  └─ 8e: 回归测试（自动生成测试用例）
Phase 9: 最终报告（before/after health score）
```

## 关键设计决策

| 决策 | 原因 |
|------|------|
| diff-aware 模式 | 没给 URL 就自动只测分支改动的页面 |
| 原子提交 | 一个 bug 一个 commit，方便 revert |
| before/after 截图对 | 视觉证据，不是口头说"修好了" |
| 自动生成回归测试 | 修了 bug 就写测试，防止复发 |
| CDP 模式检测 | 连了真实浏览器就不需要导 cookie |
