# `/benchmark` 技能深度注解

> 对应源文件：[`benchmark/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/benchmark/SKILL.md.tmpl)
> 性能回归检测：基线对比、Core Web Vitals、资源大小。

## 核心定位

性能不会一次性崩溃，而是千刀万剐：每个 PR 加 50ms，加 20KB，直到有一天加载要 8 秒。

用 browse daemon 的 `perf` 命令和 JS 评估，收集真实性能数据。

## 关键指标

- TTFB（首字节时间）
- FCP（首次内容绘制）
- LCP（最大内容绘制）
- CLS（累积布局偏移）
- 资源大小（JS/CSS/Images/Fonts）

## 模式

- `--baseline`：变更前捕获基线
- `--quick`：单次计时检查
- `--diff`：只测当前分支影响的页面
- `--trend`：显示历史趋势
