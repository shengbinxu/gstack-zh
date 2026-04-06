# `/gstack-upgrade` 技能深度注解

> 对应源文件：[`gstack-upgrade/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/gstack-upgrade/SKILL.md.tmpl)
> 升级 gstack。

---

## 功能

检测安装方式（全局 vs 项目内）→ 拉取最新版本 → 运行迁移脚本 → 重新构建 → 显示更新内容。

**迁移脚本**：`gstack-upgrade/migrations/` 里的脚本自动处理格式变更、旧文件清理等。
