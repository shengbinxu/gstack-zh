# `/browse` 技能深度注解

> 对应源文件：[`browse/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/browse/SKILL.md.tmpl)
> 无头浏览器基础工具——gstack 的"眼睛"。

---

## 这个技能是什么？

`/browse` 是 gstack 所有浏览器交互的基础层。

**守护进程模型**：长驻 Chromium 进程，持久状态，随机端口 10000-60000。
不是每次启动新浏览器——会话在命令间保持。

**~100ms/命令**：navigate → click → screenshot → snapshot 极快。

**被其他技能依赖**：/qa、/design-review、/canary、/benchmark 都通过 browse 操作浏览器。

---

## 核心命令

```
$B goto <url>         导航
$B click <selector>   点击
$B fill <sel> <text>  填写
$B screenshot <file>  截图
$B snapshot           DOM 快照（可视化 + 交互元素）
$B snapshot -D        Diff 快照（对比上次）
$B console --errors   查看 console 错误
$B status             守护进程状态
```

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 守护进程 | 会话持久，不重复启动 |
| ~100ms | 快到可以在每步截图 |
| snapshot -D | Before/after diff 是核心能力 |
