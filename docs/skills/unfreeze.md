# `/unfreeze` 技能深度注解

> 对应源文件：`unfreeze/SKILL.md.tmpl`
> 清除 /freeze 设定的编辑限制。

## 功能

删除 `~/.gstack/freeze-dir.txt`，恢复对所有目录的编辑权限。

hooks 仍然注册在会话中，但由于状态文件不存在，所有操作都会被允许。要重新冻结，再跑 `/freeze`。
