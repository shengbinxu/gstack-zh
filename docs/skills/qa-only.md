# `/qa-only` 技能深度注解

> 对应源文件：[`qa-only/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/qa-only/SKILL.md.tmpl)

## 核心定位

`/qa-only` = 只报告不修复的 QA 版本。产出结构化 bug 报告（含截图、复现步骤、health score），但 **NEVER** 改代码。

与 `/qa` 的区别：`/qa` = 测试+修复+验证循环；`/qa-only` = 纯报告。

适用场景：给别人提 bug report、外部系统 QA、只想知道问题不想立刻修。
