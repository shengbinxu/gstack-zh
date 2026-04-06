# `/careful` 技能深度注解

> 对应源文件：[`careful/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/careful/SKILL.md.tmpl)
> 破坏性命令守卫：在危险操作前警告。

## 保护的模式

| 模式 | 示例 | 风险 |
|------|------|------|
| `rm -rf` | `rm -rf /var/data` | 递归删除 |
| `DROP TABLE` | `DROP TABLE users;` | 数据丢失 |
| `TRUNCATE` | `TRUNCATE orders;` | 数据丢失 |
| `git push --force` | `git push -f origin main` | 历史重写 |
| `git reset --hard` | `git reset --hard HEAD~3` | 未提交工作丢失 |
| `kubectl delete` | `kubectl delete pod` | 生产影响 |
| `docker system prune` | `docker system prune -a` | 容器/镜像丢失 |

## 安全例外

允许不警告：`rm -rf node_modules`、`.next`、`dist`、`__pycache__`、`.cache`、`build`、`coverage`

## 实现

通过 PreToolUse hook 在每次 Bash 执行前检查命令内容。
