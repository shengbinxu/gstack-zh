# `/browse` 技能深度注解

> 对应源文件：[`browse/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/browse/SKILL.md.tmpl)
> 无头浏览器基础工具——gstack 的"眼睛"。详细架构见 [browse-daemon.md](../browse-daemon.md)。

---

## 这个技能是什么？

`/browse` 是 SKILL.md 层面的浏览器使用指南，教 Claude 如何使用 browse 守护进程。

**preamble-tier: 1**（最简），因为 browse 是底层工具，不需要评审链/学习记录等上下文。

**只允许 3 个工具**：Bash（执行 $B 命令）、Read（读文件）、AskUserQuestion。
没有 Write/Edit——browse 不改代码。

---

## 核心 QA 模式

模板提供了 7 个标准使用模式（"食谱"）：

```
1. 验证页面加载
   $B goto → $B text → $B console → $B is visible

2. 测试用户流程
   $B goto → $B snapshot -i → $B fill → $B click → $B snapshot -D

3. 验证操作结果
   $B snapshot → [执行操作] → $B snapshot -D → 检查 diff

4. 响应式测试
   $B responsive 375,768,1024,1440 → 检查每个断点

5. 表单测试
   $B forms → $B fill → $B click → $B snapshot -D

6. 错误调试
   $B console --errors → $B network → 截图

7. 截图证据
   $B screenshot bug.png → $B snapshot -a annotated.png
```

---

## Snapshot 是核心

`$B snapshot` 把页面变成 AI 可读的结构化文本：

```
$B snapshot          完整 ARIA 树 + @ref
$B snapshot -i       只保留可交互元素（按钮/链接/输入框）
$B snapshot -D       与上次的 unified diff（最常用！）
$B snapshot -a       截图 + 红色标注框
$B snapshot -c       移除空节点（紧凑模式）
$B snapshot -d 3     限制深度到 3 层
$B snapshot -s ".nav" 只看导航区域
```

**-D（diff 模式）是 gstack 浏览器交互的灵魂**：
"执行操作前 snapshot → 操作 → snapshot -D → 看什么变了"。

---

## 与其他技能的关系

```
/browse ← 基础层
   ├─ /qa          用 browse 测试 + 修复
   ├─ /qa-only     用 browse 测试（不修复）
   ├─ /design-review 用 browse 截图 + 视觉审计
   ├─ /canary      用 browse 监控生产
   ├─ /benchmark   用 browse 测量性能
   └─ /devex-review 用 browse 测试开发者体验
```

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| preamble-tier 1 | 底层工具，不需要重上下文 |
| 7 个食谱模式 | 教 AI "怎么用"而不只是"能做什么" |
| snapshot -D 为核心 | Before/after diff 是最有价值的操作 |
| 只允许 3 工具 | 只读/只执行，不改代码 |
