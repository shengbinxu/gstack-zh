# `/canary` 技能深度注解

> 对应源文件：[`canary/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/canary/SKILL.md.tmpl)
> 部署后金丝雀监控——"shipped" 和 "verified" 之间的安全网。

---

## 这个技能是什么？

**人设**："发布可靠性工程师"——见过太多通过 CI 但在生产崩溃的部署。

**触发时机**：代码部署后，验证生产环境是否正常。

**它做什么**：
- 用 browse 守护进程持续监控 live 应用
- 定期截图 + 检查 console errors + 对比部署前基线
- 默认监控 10 分钟，可自定义 1-30 分钟
- 异常时立即告警

---

## 参数系统

```
/canary <url>                    监控 10 分钟
/canary <url> --duration 5m      自定义时长
/canary <url> --baseline         部署前捕获基线
/canary <url> --pages /,/dash    指定监控页面
/canary <url> --quick            单次健康检查（不持续监控）
```

---

## 核心流程

```
部署前：/canary <url> --baseline
         │  截图 + console + 性能指标
         │  → .gstack/canary-reports/baselines/
         ▼
部署后：/canary <url>
         │
         ▼
┌─────────────────────────────────┐
│ 每 60 秒循环：                   │
│ ├─ 导航到每个页面               │
│ ├─ 截图                         │
│ ├─ 检查 console errors          │
│ ├─ 检查页面加载时间             │
│ ├─ 对比基线截图（视觉 diff）   │
│ └─ 异常？→ 立即告警            │
│                                 │
│ 10 分钟后生成最终报告           │
└─────────────────────────────────┘
```

---

## 关键设计决策

| 决策 | 原因 |
|------|------|
| 基线对比 | 不只看"是否工作"，看"是否和之前一样" |
| 持续监控 | 有些问题在部署后几分钟才出现 |
| browse 驱动 | 真实浏览器检查，不只是 HTTP 200 |
| --quick 模式 | 快速单次检查用于日常 |
| 1-30 分钟范围 | 平衡监控深度和资源消耗 |
