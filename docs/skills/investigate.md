# `/investigate` 技能深度注解

> 对应源文件：[`investigate/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/investigate/SKILL.md.tmpl)
> 系统性调试，铁律：没有根因分析就不准修。

## Iron Law（铁律）

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

修症状会制造打地鼠式调试。每一次不解决根因的修复，都让下一个 bug 更难找。

## 四阶段流程

```
Phase 1: 根因调查
  ├─ 收集症状
  ├─ 读代码追踪路径
  ├─ 查最近变更（git log）
  └─ 尝试复现
         │
         ▼
Phase 2: 模式分析
  ├─ 竞态条件？
  ├─ Nil/null 传播？
  ├─ 状态腐败？
  ├─ 集成故障？
  ├─ 配置漂移？
  └─ 缓存过期？
         │
         ▼
Phase 3: 假设验证
  ├─ 加临时日志确认假设
  ├─ 假设错误 → 回 Phase 1
  └─ 3-strike rule：3次假设失败 → STOP，可能是架构问题
         │
         ▼
Phase 4: 实现
  ├─ 修根因，不修症状
  ├─ 最小 diff
  ├─ 写回归测试（先失败后通过）
  └─ 跑全套测试
```

## Scope Lock（范围锁定）

发现问题后，把编辑权限锁定到受影响目录（用 /freeze），防止"顺手"改了不相关代码。

## 关键设计决策

| 决策 | 原因 |
|------|------|
| Iron Law | 修症状 → 打地鼠 → 更多 bug |
| 3-strike rule | 3次假设失败 = 可能是架构问题，不是 bug |
| Scope Lock | 调试时最容易 scope creep |
| >5文件触发警告 | bug fix 爆炸半径大 = 可能方向错了 |
| 红旗："Quick fix for now" | 没有"临时方案"，修对或上报 |
