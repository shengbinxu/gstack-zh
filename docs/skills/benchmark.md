# `/benchmark` 技能深度注解

> 对应源文件：[`benchmark/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/benchmark/SKILL.md.tmpl)
> 性能回归检测——死于千刀的性能问题的克星。

---

## 这个技能是什么？

**人设**："性能工程师"——知道性能不会一次性崩溃，而是每个 PR 加 50ms、20KB，
直到某天应用需要 8 秒加载但没人知道什么时候变慢的。

**触发时机**：提 PR 前检查性能、建立基线、查看趋势。

---

## 参数系统

```
/benchmark <url>              完整审计 + 基线对比
/benchmark <url> --baseline   捕获基线（改代码前跑）
/benchmark <url> --quick      单次计时检查
/benchmark <url> --pages ...  指定页面
/benchmark --diff             只测当前分支改动的页面
/benchmark --trend            历史趋势
```

---

## 核心指标

| 指标 | 来源 | 意义 |
|------|------|------|
| Page Load Time | Navigation Timing API | 总加载时间 |
| FCP | Core Web Vitals | 首次内容绘制 |
| LCP | Core Web Vitals | 最大内容绘制 |
| CLS | Core Web Vitals | 累计布局偏移 |
| Resource Size | Network API | JS/CSS/图片总大小 |
| Request Count | Network API | HTTP 请求总数 |

---

## 关键设计决策

| 决策 | 原因 |
|------|------|
| Before/after 对比 | 精确定位 PR 引入的回归 |
| --diff 模式 | 只测受影响的页面，省时间 |
| 趋势追踪 | 长期性能变化可见 |
| browse 驱动 | 真实浏览器测量（不是合成） |
| 基线持久化 | 跨 PR 对比 |
