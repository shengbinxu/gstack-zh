# `/health` 技能深度注解

> 对应源文件：`health/SKILL.md.tmpl`
> 代码质量仪表盘：类型检查 + linter + 测试 + 死代码。

## 核心定位

Staff Engineer 管理 CI 仪表盘。代码质量不是单一指标，是复合分数。跑所有可用工具，评分，追踪趋势。

**HARD GATE：不修任何问题。** 只产出仪表盘和建议。

## 自动检测的工具

| 工具 | 检测方式 |
|------|---------|
| TypeScript | tsconfig.json |
| Biome/ESLint | biome.json / .eslintrc.* |
| Ruff/Pylint | pyproject.toml |
| pytest/bun test/cargo test/go test | 各框架标志文件 |

## 加权复合分数 0-10

每个维度评分后加权合成。趋势追踪显示质量是在提升还是下滑。
