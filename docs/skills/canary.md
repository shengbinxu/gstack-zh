# `/canary` 技能深度注解

> 对应源文件：[`canary/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/canary/SKILL.md.tmpl)
> 部署后金丝雀监控。

---

## 这个技能是什么？

部署后持续监控 live 应用：console errors、性能回归、页面故障。

**核心**：browse 定期截图 → 对比部署前基线 → 异常告警

**不做什么**：不修代码——只监控和报告。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 定期截图 | 可视化监控 |
| 对比基线 | 部署前 vs 后 |
| browse 驱动 | 真实浏览器检查 |
