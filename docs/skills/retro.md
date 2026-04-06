# `/retro` 技能深度注解

> 对应源文件：[`retro/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/retro/SKILL.md.tmpl)
> 周回顾：分析提交历史、工作模式、代码质量趋势。

## 核心定位

分析 git 历史，生成工程回顾。团队感知：识别每个贡献者，给出表扬和成长建议。

## 参数

| 命令 | 效果 |
|------|------|
| `/retro` | 默认最近 7 天 |
| `/retro 24h` | 最近 24 小时 |
| `/retro 14d` | 最近 14 天 |
| `/retro compare` | 本期 vs 上期对比 |
| `/retro global` | 跨项目回顾（所有 AI 编码工具） |

## 关键设计决策

- 午夜对齐窗口：`--since="2026-03-11T00:00:00"` 精确到午夜
- 团队感知：识别当前用户，分析每个贡献者
- 趋势追踪：与历史回顾对比
- Global 模式：跨项目、跨工具的全局回顾
