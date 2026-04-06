# `/setup-deploy` 技能深度注解

> 对应源文件：[`setup-deploy/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/setup-deploy/SKILL.md.tmpl)
> 配置部署。

---

## 功能

检测部署平台（Fly.io/Render/Vercel/Netlify/Heroku/GitHub Actions/自定义）→ 配置生产 URL → 配置健康检查端点 → 写入 CLAUDE.md。

一次性配置，之后 `/land-and-deploy` 自动使用。
