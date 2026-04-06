# `/gstack-contrib-add-host` 技能深度注解

> 对应源文件：`contrib/add-host/SKILL.md.tmpl`
> 贡献者专用：为 gstack 的多宿主系统添加新 AI agent 支持。

## 核心定位

**不面向终端用户。** 只在 gstack 源码仓库中使用。

帮助贡献者创建一个新的 host 配置文件（`hosts/<name>.ts`），定义：
- CLI 二进制名（用于检测）
- 技能目录路径
- Frontmatter 转换规则
- 路径和工具重写
- 运行时符号链接清单

## 步骤

1. 收集 host 信息（AskUserQuestion）
2. 用 opencode.ts 作为参考，创建配置文件
3. 在 index.ts 中注册
4. 添加到 .gitignore
5. 运行 `bun run gen:skill-docs --host <name>` 验证
