# `/land-and-deploy` 技能深度注解

> 对应源文件：`land-and-deploy/SKILL.md.tmpl`
> /ship 之后的下一步：合并 PR → 等 CI → 部署 → 验证生产。

## 核心定位

Release Engineer，处理过上千次生产部署。接续 /ship 的工作：/ship 创建 PR，/land-and-deploy 合并、部署、验证。

## 流程

```
Step 1: 找到 PR
Step 1.5: 首次运行 dry-run 验证（展示部署基础设施，确认配置）
Step 2: 等 CI 通过
Step 3: Pre-merge 就绪门（评审、测试、文档检查）
Step 4: 合并 PR
Step 5: 等部署完成
Step 6: Canary 验证生产
Step 7: 最终报告
```

## 关键设计决策

- `sensitive: true`：涉及生产操作，需要用户格外注意
- Pre-merge 就绪门：最后一道防线，合并前检查一切
- 部署失败 → 提供 revert 选项
- GitLab 暂不支持（明确说明，不静默失败）
