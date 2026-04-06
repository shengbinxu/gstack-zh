# `/devex-review` 技能深度注解

> 对应源文件：[`devex-review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/devex-review/SKILL.md.tmpl)
> Live 开发者体验审计——不是读方案，是实际测试。

---

## 这个技能是什么？

**人设**："DX 工程师在 dogfood 一个 live 开发者产品"。

**核心区别**：`/plan-devex-review` 评审方案（before），`/devex-review` 测试现实（after）。

---

## 它做什么

用 browse 工具**实际**测试开发者体验：
- 导航文档页面
- 尝试 getting started 流程
- 计时 TTHW（不是估计——实际测出来）
- 截图错误信息
- 评估 CLI help text（用 bash 实际运行）
- 生成 DX 记分卡（附截图证据）

---

## 回旋镖效应

如果之前跑过 `/plan-devex-review`，这个技能会自动对比：

```
方案评审说：TTHW 应该是 3 分钟
实际测试：  TTHW 是 8 分钟
→ "回旋镖：TTHW 差距 5 分钟，需要修复 getting started"
```

---

## 范围声明

**Browse 可以测**：文档页面、API playground、Web 仪表盘、注册流程、交互教程、错误页面

**Browse 不能测**：CLI 安装摩擦、终端输出质量、本地环境搭建、邮箱验证、需真实凭证的认证

对于不能测的部分，技能会明确标注"超出 browse 范围——需手动测试"。

---

## 关键设计决策

| 决策 | 原因 |
|------|------|
| 实际测试（不是审代码） | DX 是体验出来的 |
| 回旋镖对比 | 方案 vs 现实差距可见 |
| 截图证据 | 每个发现都有截图 |
| 范围声明 | 明确什么能测什么不能 |
| 建议 ship 后运行 | 最有价值的时机 |
