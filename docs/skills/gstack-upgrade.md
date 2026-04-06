# `/gstack-upgrade` 技能深度注解

> 对应源文件：[`gstack-upgrade/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/gstack-upgrade/SKILL.md.tmpl)
> 升级 gstack 到最新版本。

---

## 核心流程

```
/gstack-upgrade
     │
     ▼
┌─────────────────────────┐
│ 1. 检测安装方式         │
│    全局 vs 项目内       │
├─────────────────────────┤
│ 2. 拉取最新版本         │
│    git pull / fetch     │
├─────────────────────────┤
│ 3. 运行迁移脚本         │
│    gstack-upgrade/      │
│    migrations/*.sh      │
├─────────────────────────┤
│ 4. 重新构建             │
│    ./setup              │
├─────────────────────────┤
│ 5. 显示更新内容         │
│    CHANGELOG diff       │
└─────────────────────────┘
```

**迁移脚本**：`gstack-upgrade/migrations/` 里的脚本处理升级时的格式变更、旧文件清理等。
每个迁移是幂等的（可以安全重跑）。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 迁移脚本 | 自动处理破坏性变更 |
| 幂等迁移 | 安全重跑 |
| 显示 CHANGELOG | 知道升级了什么 |
