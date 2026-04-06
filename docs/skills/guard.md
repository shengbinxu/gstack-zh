# `/guard` 技能深度注解

> 对应源文件：[`guard/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/guard/SKILL.md.tmpl)
> 最大安全模式 = /careful + /freeze 组合。

## 核心定位

同时启用：
1. **破坏性命令警告**（/careful）：rm -rf、DROP TABLE、force-push 等
2. **目录限制编辑**（/freeze）：只能编辑指定目录

适用场景：接触生产环境、调试 live 系统、共享环境操作。

## hooks 机制

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"    → check-careful.sh（破坏性命令检查）
    - matcher: "Edit"    → check-freeze.sh（目录边界检查）
    - matcher: "Write"   → check-freeze.sh（目录边界检查）
```

这是 gstack 的 hooks 系统：在工具执行前拦截并检查。
