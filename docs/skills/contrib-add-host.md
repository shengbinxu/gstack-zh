# `/gstack-contrib-add-host` 技能深度注解

> 对应源文件：[`contrib/add-host/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/contrib/add-host/SKILL.md.tmpl)
> 贡献者工具：为 gstack 添加新 AI 宿主支持。

---

## 这个技能是什么？

**仅贡献者使用**——不安装给普通用户（在 `contrib/` 目录下）。

指导贡献者为 gstack 添加新的 AI 宿主（如 Cursor, Kiro, OpenCode 等）。

---

## 核心步骤

```
1. 创建 hosts/<name>.ts
   └─ 实现 HostConfig 接口（见 scripts/host-config.ts）

2. 注册到 hosts/index.ts
   └─ 添加到 ALL_HOST_CONFIGS 数组

3. 更新 gen-skill-docs.ts（如需特殊处理）

4. 可选：创建 host adapter
   └─ scripts/host-adapters/<name>-adapter.ts

5. 运行 bun run gen:skill-docs --host <name>
   └─ 验证生成的 SKILL.md 文件
```

详见 [template-pipeline.md](../template-pipeline.md) 了解完整的宿主配置系统。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 在 contrib/ 下 | 不安装给用户 |
| 技能形式（不是文档） | 让 AI 辅助完成添加过程 |
| 引用 HostConfig | 确保类型安全 |
