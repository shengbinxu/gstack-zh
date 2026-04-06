# `/benchmark` 技能深度注解

> 对应源文件：[`benchmark/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/benchmark/SKILL.md.tmpl)
> 性能回归检测。

---

## 这个技能是什么？

用 browse 建立性能基线 → 每次 PR 对比 → 追踪趋势。

**指标**：页面加载时间、Core Web Vitals、资源大小。

**核心**：不是一次性跑 Lighthouse——是持续追踪，发现回归。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| Before/after 对比 | 精确定位回归 |
| 趋势追踪 | 长期性能可见 |
| browse 驱动 | 真实浏览器测量 |
