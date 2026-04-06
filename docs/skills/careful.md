# `/careful` 技能深度注解

> 对应源文件：[`careful/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/careful/SKILL.md.tmpl)
> 破坏性命令守卫。

---

## 这个技能是什么？

在 `rm -rf`、`DROP TABLE`、`git reset --hard`、`kubectl delete` 等破坏性命令前弹出警告。

**不阻止执行**——只是在执行前提醒，用户可以覆盖。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 警告不阻止 | 尊重用户判断 |
| 覆盖面广 | git/docker/k8s/SQL/rm 全覆盖 |
