# `/learn` 技能深度注解

> 对应源文件：[`learn/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/learn/SKILL.md.tmpl)
> 管理项目学习记录：查看、搜索、清理、导出。

## 核心定位

Staff Engineer 维护团队 wiki。查看 gstack 在各会话中学到的经验，搜索相关知识，清理过期条目。

**HARD GATE：不实现代码变更。** 只管理 learnings。

## 命令

| 命令 | 功能 |
|------|------|
| `/learn` | 显示最近 20 条 |
| `/learn search <query>` | 搜索 |
| `/learn prune` | 清理过期/矛盾条目 |
| `/learn export` | 导出 |
| `/learn stats` | 统计 |
| `/learn add` | 手动添加 |

## 数据存储

`~/.gstack/projects/{slug}/learnings.jsonl` — 每个项目一个 JSONL 文件，由其他技能（/review, /ship, /investigate）自动写入。
