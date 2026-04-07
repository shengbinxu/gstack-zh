# `/canary` 技能逐段中英对照注解

> 对应源文件：[`canary/SKILL.md`](https://github.com/garrytan/gstack/blob/main/canary/SKILL.md)（807 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## Frontmatter（元数据区）

```yaml
---
name: canary
preamble-tier: 2
version: 1.0.0
description: |
  Post-deploy canary monitoring. Watches the live app for console errors,
  performance regressions, and page failures using the browse daemon. Takes
  periodic screenshots, compares against pre-deploy baselines, and alerts
  on anomalies.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
---
```

**中文翻译**：

- **preamble-tier: 2**：中等级别 Preamble（共 4 级）。canary 是监控工具，不需要完整的 repo 模式检测，但需要基本的会话追踪和 telemetry。
- **description**：部署后 Canary 监控。使用 browse daemon 监视线上应用的 console 错误、性能回归和页面故障。定期截图，与部署前基线对比，在发现异常时报警。
- **allowed-tools**：包含 `Write`（保存截图路径、报告、基线 JSON），但**没有 Edit**——canary 是纯观测工具，从不修改代码。

> **设计原理：为什么 preamble-tier 是 2 而不是 4？**
> canary 是个观测工具，不做决策、不改代码。它不需要 tier 4 的完整 repo 模式检测和 staging 环境探测。tier 2 提供足够的基础设施（更新检查、telemetry、session 追踪）而不增加不必要的启动开销。

---

## Preamble 展开区

`canary` 使用 **tier 2 Preamble**，包含：

1. **更新检查**：`gstack-update-check`
2. **会话追踪**：`~/.gstack/sessions/$PPID`
3. **基本环境变量**：`BRANCH`、`PROACTIVE`、`SKILL_PREFIX`、`REPO_MODE`
4. **Telemetry**：记录技能使用（skill-usage.jsonl）
5. **SPAWNED_SESSION**：若在 orchestrator 子 session 中，跳过所有 AskUserQuestion

**Browse 守护进程初始化**：

canary 在 Preamble 之后运行标准的 browse setup 检查：

```bash
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
B=""
[ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="..."
[ -z "$B" ] && B=~/.claude/skills/gstack/browse/dist/browse
```

若 `NEEDS_SETUP`，提示用户一次性构建（约 10 秒），然后停止等待确认。

---

## 核心角色设定

> **原文**：
> ```
> You are a Release Reliability Engineer watching production after a deploy. You've
> seen deploys that pass CI but break in production — a missing environment variable,
> a CDN cache serving stale assets, a database migration that's slower than expected
> on real data. Your job is to catch these in the first 10 minutes, not 10 hours.
> ```

**中文**：你是一个**发布可靠性工程师**，在部署后监视生产环境。你见过通过 CI 却在生产环境崩溃的部署——缺失的环境变量、CDN 缓存提供陈旧资源、数据库迁移在真实数据上比预期慢。你的工作是在最初 10 分钟内捕获这些问题，而不是 10 小时后。

> **设计原理：为什么 CI 通过了还需要 canary？**
> CI 在测试数据库、测试环境、测试流量下运行。生产环境有：真实用户数据、CDN 缓存状态、实际负载、真实的环境变量配置。这些差异导致"CI 绿，prod 红"是软件工程中最常见的故障模式之一。

---

## 用户调用参数

```
/canary <url>                          # 部署后监控 10 分钟
/canary <url> --duration 5m           # 自定义监控时长（1m 到 30m）
/canary <url> --baseline              # 部署前捕获基线（部署前运行）
/canary <url> --pages /,/dashboard    # 指定监控哪些页面
/canary <url> --quick                 # 单次健康检查（不持续监控）
```

> **设计原理：`--baseline` 是整个技能的灵魂**
> 如果没有基线，canary 只能做绝对值判断（"这个页面有 3 个 console 错误"）。有了基线，它可以做差异判断（"比部署前多了 2 个 console 错误"）。差异判断几乎消除了误报——一个本来就有 3 个错误的页面，部署后还是 3 个，这不是问题。

---

## 基线与当前对比机制

这是 canary 最核心的设计，值得深入解释：

```
部署前运行：/canary <url> --baseline
                    │
                    ▼
        为每个页面捕获：
        ├─ 截图（.gstack/canary-reports/baselines/<page>.png）
        ├─ console 错误数量
        ├─ 页面加载时间（毫秒）
        └─ 页面文本内容快照
                    │
                    ▼
        保存到 .gstack/canary-reports/baseline.json：
        {
          "url": "https://myapp.com",
          "timestamp": "2024-01-15T14:00:00Z",
          "branch": "feat/dark-mode",
          "pages": {
            "/": { "screenshot": "baselines/home.png",
                   "console_errors": 0, "load_time_ms": 450 },
            "/dashboard": { "console_errors": 3, "load_time_ms": 800 }
          }
        }

部署后运行：/canary <url>
                    │
                    ▼
        每 60 秒，对比基线：
        ├─ / 当前 errors=0，基线 0 → 无变化 ✓
        ├─ / 当前 load=480ms，基线 450ms → 正常波动 ✓
        ├─ /dashboard 当前 errors=5，基线 3 → 新增 2 个！ALERT
        └─ /dashboard 当前 load=2000ms，基线 800ms → 2.5x 回归！ALERT
```

> **设计原理：告警基于变化，而非绝对值**
> 这是最关键的设计决策。如果 `/dashboard` 在部署前就有 3 个 console 错误（可能是已知的第三方脚本问题），那么部署后还是 3 个，不应该告警。新增了 2 个，才是告警。基于绝对值的告警工具会让工程师陷入"告警疲劳"，最终关掉所有告警。

---

## Phase 1-2：初始化与基线捕获

> **原文（Phase 2 Baseline）**：
> ```
> $B goto <page-url>
> $B snapshot -i -a -o ".gstack/canary-reports/baselines/<page-name>.png"
> $B console --errors
> $B perf
> $B text
> ```
> Then STOP and tell the user: "Baseline captured. Deploy your changes, then run
> `/canary <url>` to monitor."

**中文**：`--baseline` 模式的工作流：访问页面 → 截图 → 检查 console 错误 → 测量加载时间 → 获取文本内容 → 保存到 `baseline.json`。完成后停止，等用户部署后再调用 canary 进行对比。

---

## Phase 3：页面发现

> **原文**：
> ```
> $B goto <url>
> $B links
> $B snapshot -i
> ```
> Extract the top 5 internal navigation links. Always include the homepage.

**中文**：如果用户没有指定 `--pages`，技能自动发现前 5 个内部导航链接（首页始终包含）。然后通过 AskUserQuestion 让用户确认监控哪些页面。

---

## Phase 4：无基线时的参考点

> **原文**：
> ```
> If no baseline.json exists, take a quick snapshot now as a reference point.
> These become the reference for detecting regressions during monitoring.
> ```

**中文**：如果没有 `--baseline` 预捕获的基线，canary 在开始监控前立即截图作为参考。这样可以检测"监控期间出现的变化"，但无法反映"部署本身引入的变化"。

> **设计原理：无基线时的降级行为**
> 没有部署前基线，canary 降级为"实时健康检查"模式：只能检测监控期间出现的新问题，不能与部署前状态对比。这仍然有价值（比如检测间歇性错误），但不如有基线的完整模式精确。

---

## Phase 5：持续监控循环

> **原文**：
> ```
> Monitor for the specified duration. Every 60 seconds, check each page:
> $B goto, $B snapshot, $B console --errors, $B perf
> ```

**中文**：监控循环每 60 秒执行一次完整检查。四个告警级别：

| 告警类型 | 触发条件 | 级别 |
|---------|---------|------|
| 页面加载失败 | `goto` 返回错误或超时 | CRITICAL |
| 新增 console 错误 | 当前错误数 > 基线错误数 | HIGH |
| 性能回归 | 加载时间 > 基线的 2 倍 | MEDIUM |
| 新增 404 链接 | 基线中不存在的 404 | LOW |

**防误报机制**：

> **原文**：
> ```
> Don't cry wolf. Only alert on patterns that persist across 2 or more
> consecutive checks. A single transient network blip is not an alert.
> ```

**中文**：不要"狼来了"。只对**连续 2 次或以上**检查中都存在的问题发出告警。单次的网络抖动不是告警。这个机制大幅减少了由于 CDN 波动、瞬时网络问题引起的误报。

**告警格式**：

> **原文**：
> ```
> CANARY ALERT
> ════════════
> Time:     check #3 at 180s
> Page:     /dashboard
> Type:     HIGH
> Finding:  2 new console errors (ReferenceError: darkMode is not defined)
> Evidence: .gstack/canary-reports/screenshots/dashboard-3.png
> Baseline: 3 errors
> Current:  5 errors
> ```

**中文**：告警格式的关键设计——每次告警**必须**包含截图路径。工程师不需要去浏览器里重现，截图就是证据。

> **告警响应选项**：
> - A) 立刻调查，停止监控
> - B) 继续监控（可能是瞬时问题）
> - C) 立刻回滚
> - D) 忽略，继续监控（确认是误报）

---

## Phase 6：健康报告

> **原文**：
> ```
> CANARY REPORT — https://myapp.com
> ═════════════════════════════════
> Duration:     10 minutes
> Pages:        3 pages monitored
> Checks:       10 total checks performed
> Status:       DEGRADED
>
> Per-Page Results:
>   /             HEALTHY     0 errors    450ms
>   /dashboard    DEGRADED    2 new       1200ms (was 400ms)
>   /settings     HEALTHY     0 errors    380ms
>
> VERDICT: DEPLOY HAS ISSUES — details above
> ```

**中文**：报告保存至 `.gstack/canary-reports/{date}-canary.md` 和 `.json` 两种格式。JSON 用于后续的机器处理（比如 `/retro` 分析部署健康趋势）。

---

## Phase 7：基线更新

> **原文**：
> ```
> If the deploy is healthy, offer to update the baseline:
> A) Update baseline with current screenshots
> B) Keep old baseline
> ```

**中文**：如果部署健康，技能提议用最新截图更新基线。这样下次部署时，比较的是当前生产状态，而不是上上次部署的状态。基线跟随每次成功部署滚动更新。

---

## 与 `/land-and-deploy` 的集成关系

`/land-and-deploy` 的 Step 7 调用 canary 的核心逻辑，但有一个关键区别：

| 对比维度 | `/land-and-deploy` 内嵌 canary | 独立运行 `/canary` |
|---------|---------------------------|------------------|
| 模式 | 单次检查（`--quick`） | 持续监控（默认 10 分钟）|
| 目的 | 确认部署成功 | 捕获间歇性问题、性能漂移 |
| 失败响应 | 提供 revert 选项 | 提供多种告警响应选项 |
| 触发时机 | 部署完成后自动触发 | 用户主动调用 |

> **设计原理：为什么要把它们分开？**
> 部署验证是一次性的："这个部署成功了吗？"。Canary 监控是持续的："在接下来的时间里，这个部署有没有带来隐性问题？"。比如，一个内存泄漏可能要在 5 分钟后才会影响页面性能。把它们分开，让用户可以选择需要多少保证。

---

## 完整流程总结图

```
用户输入 /canary <url> [选项]
         │
         ├─ Phase 1：初始化
         │     ├─ browse daemon 状态检查
         │     └─ 创建目录（canary-reports / baselines / screenshots）
         │
         ├─ [--baseline 模式]
         │     ├─ 遍历每个页面：goto → snapshot → console → perf → text
         │     ├─ 写入 baseline.json
         │     └─ STOP（等待用户部署）
         │
         ├─ [正常模式]
         │     │
         │     ├─ Phase 3：页面发现
         │     │     ├─ 有 --pages → 直接使用
         │     │     └─ 无 → $B links 自动发现 + AskUserQuestion 确认
         │     │
         │     ├─ Phase 4：参考点捕获（若无 baseline.json）
         │     │     └─ 立即截图作为监控起点
         │     │
         │     ├─ Phase 5：持续监控循环（默认 10 分钟）
         │     │     ├─ 每 60 秒：goto → snapshot → console → perf
         │     │     ├─ 对比基线：有变化 → 检查是否连续 2 次
         │     │     │         连续 2 次 → 触发告警
         │     │     │         单次 → 记录但不告警
         │     │     └─ CRITICAL/HIGH 告警 → AskUserQuestion
         │     │           ├─ A) 调查 → 停止监控
         │     │           ├─ B) 继续（等下次检查）
         │     │           ├─ C) 立刻回滚
         │     │           └─ D) 忽略（误报）
         │     │
         │     ├─ Phase 6：健康报告
         │     │     ├─ 总体状态（HEALTHY / DEGRADED / BROKEN）
         │     │     ├─ 各页面详情（状态 / 错误数 / 平均加载时间）
         │     │     ├─ 告警汇总
         │     │     └─ 保存 .md + .json 报告
         │     │
         │     └─ Phase 7：基线更新（可选）
         │           └─ 健康部署 → 询问是否更新基线截图
         │
         └─ Telemetry（记录 skill-usage.jsonl）

关键命令参考：
  $B goto <url>              # 访问页面
  $B console --errors        # 读取 console 错误
  $B perf                    # 测量加载时间
  $B text                    # 获取页面文本
  $B snapshot -i -a -o <path># 截图（含注释）
  $B links                   # 提取页面链接
```

---

## 设计核心思路汇总表

| 设计决策 | 具体实现 | 背后原因 |
|---------|---------|---------|
| 告警基于差异，非绝对值 | 当前值 vs baseline.json | 消除"告警疲劳"，只报真正的变化 |
| 防误报：连续 2 次才告警 | 每个问题需在 2+ 次检查中持续存在 | 过滤网络抖动等瞬时问题 |
| 截图作为告警证据 | 每次告警必须包含 `Evidence: <path>` | 工程师不需要重现，截图即证据 |
| `--baseline` 预捕获机制 | 部署前运行，保存参考状态 | 实现精确的部署前后对比 |
| 基线随成功部署滚动更新 | Phase 7 提议更新基线 | 比较点始终是最近一次成功状态 |
| 有基线 vs 无基线降级 | 无基线时退化为实时健康检查 | 无基线也能用，只是精度降低 |
| 与 `/land-and-deploy` 分层 | 部署后单次验证 vs 独立持续监控 | 职责清晰，按需选择保证深度 |
| preamble-tier: 2（轻量）| 不需要完整 repo 检测 | canary 是观测工具，启动开销应该小 |
| 纯观测，不修改代码 | allowed-tools 无 Edit | 监控工具不应该意外改变被监控对象 |
| 报告双格式（.md + .json）| Phase 6 同时写两种格式 | .md 人读，.json 供 `/retro` 机器分析 |
