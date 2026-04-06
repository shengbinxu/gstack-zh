# `/land-and-deploy` 技能深度注解

> 对应源文件：[`land-and-deploy/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/land-and-deploy/SKILL.md.tmpl)
> 合并+部署+验证——接 /ship 的棒。

---

## 这个技能是什么？

`/ship` 创建 PR，`/land-and-deploy` 合并它、等待部署、验证生产。

**sensitive: true**：合并 PR 不可逆。

**人设**："部署过上千次的发布工程师"，知道两个最糟糕的感觉：合并后生产崩溃，和合并后盯着屏幕等 45 分钟。

---

## 核心流程

```
/land-and-deploy [#PR] [url]
       │
       ▼
┌──────────────────────────┐
│ Step 1: 找到 PR           │
│ └─ 当前分支 / 指定 #号   │
├──────────────────────────┤
│ Step 2: Pre-merge checks  │
│ ├─ CI 通过？             │
│ ├─ 评审批准？             │
│ └─ 无冲突？              │
├──────────────────────────┤
│ Step 3: Merge             │
│ └─ gh pr merge --squash  │
├──────────────────────────┤
│ Step 4: Wait for deploy   │
│ └─ 轮询部署状态           │
├──────────────────────────┤
│ Step 5: Canary verify     │
│ └─ browse 检查生产页面   │
│    ├─ 页面加载正常？      │
│    ├─ console 无错误？    │
│    └─ 关键功能可用？      │
├──────────────────────────┤
│ Step 6: Verdict           │
│ └─ HEALTHY / DEGRADED /  │
│    BROKEN                 │
└──────────────────────────┘
```

**只支持 GitHub**（GitLab 尚未实现）。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| sensitive: true | 合并不可逆 |
| 浏览器验证 | 不只看 CI，实际打开页面 |
| 三种裁决 | HEALTHY/DEGRADED/BROKEN |
| 接 /ship | 分工：/ship 建 PR，这个合并 |
