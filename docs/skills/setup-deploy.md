# `/setup-deploy` 技能深度注解

> 对应源文件：[`setup-deploy/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/setup-deploy/SKILL.md.tmpl)
> 一次性部署配置。

---

## 这个技能是什么？

检测部署平台 → 配置生产 URL → 配置健康检查 → 写入 CLAUDE.md。

**支持的平台**：Fly.io / Render / Vercel / Netlify / Heroku / GitHub Actions / 自定义

**一次性运行**——配置写入 CLAUDE.md 后，`/land-and-deploy` 自动读取使用。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 自动检测平台 | 不需要手动指定 |
| 写入 CLAUDE.md | 持久化，后续自动使用 |
| 一次性 | 配置不常变 |
