# `/setup-deploy` 技能深度注解

> 对应源文件：`setup-deploy/SKILL.md.tmpl`
> 一次性配置部署，让 /land-and-deploy 自动工作。

## 核心定位

检测部署平台（Fly.io / Render / Vercel / Netlify / Heroku / GitHub Actions / 自定义），生产 URL，健康检查端点，部署状态命令。写入 CLAUDE.md 持久化。

## 流程

1. 检查 CLAUDE.md 是否已有配置
2. 自动检测部署平台（从 fly.toml、render.yaml、vercel.json 等）
3. 用 AskUserQuestion 确认/补充
4. 写入 `## Deploy Configuration` 到 CLAUDE.md

跑一次之后，/land-and-deploy 读 CLAUDE.md 跳过检测。
