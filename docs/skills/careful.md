# `/careful` 技能深度注解

> 对应源文件：[`careful/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/careful/SKILL.md.tmpl)
> 破坏性命令守卫。

---

## 这个技能是什么？

在破坏性命令执行前弹出警告。用户可以覆盖每个警告。

**覆盖的命令类型**：
- `rm -rf` / `rm -r` — 递归删除
- `DROP TABLE` / `DELETE FROM` — 数据库破坏
- `git reset --hard` / `git push --force` — Git 不可逆操作
- `kubectl delete` — Kubernetes 资源删除
- `docker system prune` — Docker 清理
- `pkill` / `kill -9` — 进程终止

**不阻止执行**——只提醒。尊重用户判断。

---

## 实现机制

通过 PreToolUse hook 拦截 Bash 调用，检查命令文本中的危险模式。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 警告不阻止 | 尊重用户，不做保姆 |
| 宽覆盖 | git/docker/k8s/SQL/rm 全覆盖 |
| 用户可覆盖 | 安全网，不是防火墙 |
