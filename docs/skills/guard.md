# `/guard` 技能深度注解

> 对应源文件：[`guard/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/guard/SKILL.md.tmpl)
> 最大安全模式——/careful + /freeze 组合。

---

## 这个技能是什么？

一条命令同时启用：
1. **破坏性命令警告**（/careful）——rm -rf、DROP TABLE 等
2. **目录编辑限制**（/freeze）——只允许编辑指定目录

**用途**：碰生产环境或调试 live 系统时的双重保险。

```
/guard src/payments/
  └→ 启用 /careful（全局破坏性命令警告）
  └→ 启用 /freeze src/payments/（只允许编辑支付模块）
```

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 组合技能 | 一条命令最大安全 |
| 双重保险 | 命令保护 + 编辑范围限制 |
| 生产环境场景 | 最需要保护的时候用 |
