# `/gstack-contrib-add-host` 技能深度注解

> 对应源文件：[`contrib/add-host/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/contrib/add-host/SKILL.md.tmpl)
> 贡献者工具：添加新 AI agent 支持。

---

## 这个技能是什么？

指导贡献者为 gstack 添加新的 AI 宿主支持（如 Cursor、Kiro、OpenCode 等）。

**核心步骤**：创建 `hosts/<name>.ts` → 实现 HostConfig 接口 → 注册到 index.ts → 更新生成器

**仅贡献者使用**——不安装给普通用户。
