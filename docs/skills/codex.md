# `/codex` 技能深度注解

> 对应源文件：[`codex/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/codex/SKILL.md.tmpl)
> 多 AI 第二意见：用 OpenAI Codex CLI 获取独立评审。

## 核心定位

Codex 是"200 IQ 自闭症开发者"——直接、简洁、技术精确、挑战假设。忠实呈现它的输出，不做摘要。

## 三种模式

| 模式 | 命令 | 用途 |
|------|------|------|
| Review | `/codex review` | 独立 diff 评审，pass/fail 门 |
| Challenge | `/codex challenge` | 对抗模式，试图打破你的代码 |
| Consult | `/codex` | 问 Codex 任何问题，支持多轮对话 |

## 文件系统边界

所有发给 Codex 的 prompt 都必须加前缀指令：不要读取 SKILL.md 文件。防止 Codex 发现 gstack 技能文件并跟随其指令。
