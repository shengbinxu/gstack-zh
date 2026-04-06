# `/canary` 技能深度注解

> 对应源文件：[`canary/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/canary/SKILL.md.tmpl)
> 部署后金丝雀监控：前 10 分钟自动巡检。

## 核心定位

Release Reliability Engineer，监控部署后的生产环境。CI 通过 ≠ 生产正常。漏掉的 env var、CDN 缓存陈旧资产、慢迁移... 这些在前 10 分钟抓住，不是 10 小时。

## 流程

1. Setup：创建报告目录
2. Baseline Capture（`--baseline`）：部署前截图+性能数据
3. Deploy Watch：定期检查（每分钟一次）
   - 截图对比
   - Console 错误检查
   - 性能数据采集
   - 页面可用性验证
4. Final Report：与基线对比，异常告警

## 参数

- `--duration 5m`：自定义监控时长（默认 10 分钟）
- `--baseline`：部署前捕获基线
- `--pages /,/dashboard`：指定页面
- `--quick`：单次健康检查
