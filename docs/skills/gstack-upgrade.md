# `/gstack-upgrade` 技能深度注解

> 对应源文件：[`gstack-upgrade/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/gstack-upgrade/SKILL.md.tmpl)
> 升级 gstack 到最新版本。

## 核心定位

检测安装方式（全局 vs 项目内），执行升级，显示更新内容。

## 升级流程

1. 检查是否启用了自动升级（`auto_upgrade` 配置）
2. 如果自动升级 → 直接执行
3. 否则 AskUserQuestion：
   - 立即升级
   - 始终自动更新
   - 暂不（渐进退避：24h → 48h → 1周）
   - 永远不问

## 内联升级流程

所有技能 preamble 检测到 `UPGRADE_AVAILABLE` 时，会引用这个技能的"Inline upgrade flow"部分。升级失败时自动从 `.bak` 目录恢复。
