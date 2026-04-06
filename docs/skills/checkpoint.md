# `/checkpoint` 技能深度注解

> 对应源文件：`checkpoint/SKILL.md.tmpl`
> 保存和恢复工作状态，跨会话/跨工作区不丢失上下文。

## 核心定位

Staff Engineer 记录精细的会话笔记。捕获完整工作上下文——正在做什么、做了什么决策、还剩什么——让任何未来会话都能无缝续接。

**HARD GATE：不实现代码变更。** 只捕获和恢复上下文。

## 三个命令

| 命令 | 功能 |
|------|------|
| `/checkpoint` 或 `/checkpoint save` | 保存当前状态 |
| `/checkpoint resume` | 恢复到最近检查点 |
| `/checkpoint list` | 列出历史检查点 |

## 保存的内容

- 当前分支、commit hash
- git status（未提交变更）
- 做出的决策
- 剩余工作
- 相关文件列表
