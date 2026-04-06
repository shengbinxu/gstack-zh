# `/design-shotgun` 技能深度注解

> 对应源文件：[`design-shotgun/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/design-shotgun/SKILL.md.tmpl)
> 视觉头脑风暴：生成多个 AI 设计变体，并排比较。

## 核心定位

设计头脑风暴伙伴。生成多个 AI 设计方向，在浏览器里并排打开，迭代直到用户选定方向。

## 流程

Step 0: 检查历史设计探索（可续接）
Step 1: 收集设计需求
Step 2: 用 gstack designer 的 `variants` 命令生成 3-5 个方向
Step 3: 用 `compare` 命令打开并排比较面板
Step 4: 收集结构化反馈
Step 5: 用 `iterate` 精炼选中方向
Step 6: 保存 approved.json（供后续技能使用）
