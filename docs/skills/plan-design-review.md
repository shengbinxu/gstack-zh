# `/plan-design-review` 技能深度注解

> 对应源文件：[`plan-design-review/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/plan-design-review/SKILL.md.tmpl)
> 设计师视角评审方案（不是评审 live 站点，那是 /design-review）。

## 核心定位

高级产品设计师评审**方案**，找缺失的设计决策并**加进方案里**。输出是更好的方案，不是关于方案的文档。

## gstack designer 集成

```
如果方案有 UI 且 designer 可用 → 直接生成 mockup
不要问许可。不要写文字描述。直接展示。
没有视觉的设计评审只是意见。
```

命令：`generate`（单张）、`variants`（多方向）、`compare`（并排）、`iterate`（迭代）、`check`（跨模型质量门）。

## 9 条设计原则

1. 空状态是功能 2. 每个页面有层次 3. 具体性 > 氛围 4. 边界情况是用户体验
5. AI slop 是敌人 6. 响应式 ≠ 在手机上堆叠 7. 无障碍不可选 8. 减法为默认
9. 信任在像素级别赢得或失去
