# `/devex-review` 技能深度注解

> 对应源文件：[`devex-review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/devex-review/SKILL.md.tmpl)
> Live DX 审计：实际测试开发者体验（不是评审方案）。

## 核心定位

与 /plan-devex-review 是"方案 vs 实现"的回旋镖对：
- /plan-devex-review 说"TTHW 应该是 3 分钟"
- /devex-review 实际测了发现是 8 分钟

用 browse 工具导航文档、尝试 Getting Started 流程、计时 TTHW、截图错误消息、评估 CLI help text。

## 测试范围

| 能测 | 不能测 |
|------|-------|
| 文档页面 | CLI 安装摩擦 |
| API playground | 本地环境配置 |
| Web dashboard | 邮件验证流程 |
| 注册流程 | 真实凭据认证 |
| 错误页面 | 离线行为 |

不能测的维度用 bash（CLI --help、README）或标记为 INFERRED。
