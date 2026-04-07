# `/benchmark` 技能逐段中英对照注解

> 对应源文件：[`benchmark/SKILL.md`](https://github.com/garrytan/gstack/blob/main/benchmark/SKILL.md)（673 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## 一、技能定位与核心价值

`/benchmark` 是 gstack 的**性能回归检测技能**。它解决的问题是：**性能不是突然变差的，而是被一千个小提交慢慢杀死的。**

**原文（核心描述）**：
```
You are a Performance Engineer who has optimized apps serving millions of requests.
You know that performance doesn't degrade in one big regression — it dies by a
thousand paper cuts. Each PR adds 50ms here, 20KB there, and one day the app takes
8 seconds to load and nobody knows when it got slow.

Your job is to measure, baseline, compare, and alert.
```

**中文**：你是一个优化过百万请求量 app 的性能工程师。性能不是一次大退化搞垮的，而是被无数小 PR 一点点蚕食的——这个 PR 多了 50ms，那个多了 20KB，最终 app 加载需要 8 秒，没人知道是什么时候变慢的。

你的工作是：**测量、建立基线、比较、告警**。

### 与其他技能的关系

```
/qa ──────────→ 功能是否正确？（黑盒测试）
/benchmark ──→ 性能是否退化？（指标对比）
/canary ─────→ 部署后是否健康？（持续监控）
/health ─────→ 代码质量是否下降？（静态分析）
```

| 技能 | 关注点 | 触发时机 |
|------|--------|---------|
| `/qa` | 功能正确性、Bug | 功能开发后 |
| `/benchmark` | 性能指标、包体积 | **每次 PR 合并前** |
| `/canary` | 部署后实时健康状态 | 部署后持续监控 |
| `/health` | 代码质量、技术债 | 周期性评估 |

### 在 CI/CD 流水线中的位置

```
开发 → 提 PR → [/benchmark --baseline 已有] → [/benchmark 比较] → 通过 → /land-and-deploy → /canary
                   ↑                              ↑
            PR 合并前运行                    报告性能变化
            检测退化
```

---

## 二、Frontmatter（元数据区）

```yaml
---
name: benchmark
preamble-tier: 1
version: 1.0.0
description: |
  Performance regression detection using the browse daemon. Establishes
  baselines for page load times, Core Web Vitals, and resource sizes.
  Compares before/after on every PR. Tracks performance trends over time.
  Use when: "performance", "benchmark", "page speed", "lighthouse", "web vitals",
  "bundle size", "load time". (gstack)
  Voice triggers (speech-to-text aliases): "speed test", "check performance".
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/benchmark` 触发。
- **preamble-tier: 1**: 最精简的 Preamble 级别。包含会话追踪、版本检查等基础机制，省略了高级上下文（如路由规则注入、设计工具）。性能检测是工具性技能，不需要太多前置交互。
- **description**: 使用浏览器守护进程进行性能回归检测。建立页面加载时间、Core Web Vitals、资源大小的基线。对每个 PR 做前后对比。追踪跨时间的性能趋势。
- **Voice triggers**: 语音识别别名，说"speed test"或"check performance"会触发此技能。
- **allowed-tools**: 注意**没有 Edit**——性能检测是只读的，不修改项目代码。有 Write 是为了写基线文件（`.gstack/benchmark-reports/`）。

> **设计原理：为什么是 Tier 1？**
> Tier 1 是最精简的 Preamble。性能测试通常在 CI 流水线中自动运行，不需要太多交互式引导（遥测提示、路由规则等）。用最少的初始化代码，让测试尽快开始。

---

## 三、Preamble（前置运行区）

Preamble 内容与 `/setup-deploy` 的 Tier 2 部分高度重叠，主要差异在于 Tier 1 版本**更精简**。核心初始化代码相同：

```bash
_UPD=$(~/.claude/skills/gstack/bin/gstack-update-check 2>/dev/null || .claude/skills/gstack/bin/gstack-update-check 2>/dev/null || true)
mkdir -p ~/.gstack/sessions
touch ~/.gstack/sessions/"$PPID"
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
source <(~/.claude/skills/gstack/bin/gstack-repo-mode 2>/dev/null) || true
```

**关键变量说明**：

| 变量 | 含义 | 用途 |
|------|------|------|
| `_BRANCH` | 当前 git 分支 | 用于基线文件命名和比较标记 |
| `_SESSION_ID` | `$$-$(date +%s)` | 本次会话唯一 ID |
| `_TEL_START` | 技能开始时间戳 | 用于计算会话时长 |
| `REPO_MODE` | 团队/个人模式 | 影响学习系统路径 |

---

## 四、浏览器守护进程初始化（SETUP）

这是 `/benchmark` 的核心依赖，位于源文件第 426-461 行。

**原文**：
```bash
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
B=""
[ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="$_ROOT/.claude/skills/gstack/browse/dist/browse"
[ -z "$B" ] && B=~/.claude/skills/gstack/browse/dist/browse
if [ -x "$B" ]; then
  echo "READY: $B"
else
  echo "NEEDS_SETUP"
fi
```

**中文**：检测 gstack 的无头浏览器守护进程（browse daemon）是否已编译。查找顺序：
1. 项目本地（团队模式）：`{project-root}/.claude/skills/gstack/browse/dist/browse`
2. 用户全局（个人模式）：`~/.claude/skills/gstack/browse/dist/browse`

如果输出 `NEEDS_SETUP`：
```
1. 提示用户: "gstack browse 需要一次性构建（约 10 秒）。是否继续？"
2. STOP 并等待
3. 运行: cd <SKILL_DIR> && ./setup
```

> **设计原理：为什么用自己的浏览器守护进程？**
> `$B`（browse daemon）是 gstack 的核心竞争力。它比 Puppeteer/Playwright 更轻量，专门为 AI 工具链设计：
> - `$B perf` — 直接返回性能数据，不需要写测试代码
> - `$B eval "..."` — 在页面上下文中执行 JS，获取浏览器内部数据
> - `$B goto <url>` — 导航到页面，支持 SPA 路由
>
> 这让 AI 能"看到"浏览器真实测量的性能数据，而非估算值。

---

## 五、命令行参数系统

**原文**：
```
## Arguments
- /benchmark <url>             — full performance audit with baseline comparison
- /benchmark <url> --baseline  — capture baseline (run before making changes)
- /benchmark <url> --quick     — single-pass timing check (no baseline needed)
- /benchmark <url> --pages /,/dashboard,/api/health — specify pages
- /benchmark --diff            — benchmark only pages affected by current branch
- /benchmark --trend           — show performance trends from historical data
```

**中文**：六种调用模式，覆盖不同场景：

| 模式 | 命令 | 使用场景 |
|------|------|---------|
| **完整审计** | `/benchmark <url>` | 标准 PR 前性能检查 |
| **基线捕获** | `/benchmark <url> --baseline` | **开始改动前先建立基线** |
| **快速检查** | `/benchmark <url> --quick` | 快速验证单次改动影响 |
| **指定页面** | `/benchmark <url> --pages /,/dashboard` | 针对性检测关键页面 |
| **影响范围** | `/benchmark --diff` | 只检测当前 PR 影响的页面 |
| **历史趋势** | `/benchmark --trend` | 跨 PR 性能变化分析 |

### 最佳工作流

```
1. 开始改动前:   /benchmark https://myapp.com --baseline
2. 开发、提交、推送
3. PR 合并前:    /benchmark https://myapp.com
   (自动与 baseline 对比，输出回归报告)
4. 周期性复查:   /benchmark --trend
   (查看过去 N 次的性能走势)
```

---

## 六、核心工作流：九个阶段

### 6.1 整体流程图

```
/benchmark <url>
    │
    ▼
Phase 1: Setup（目录初始化）
    │
    ▼
Phase 2: Page Discovery（页面发现）
    │
    ├─ --diff 模式 ──→ git diff 找出受影响的页面
    └─ 普通模式  ──→ 自动发现或用 --pages 指定
    │
    ▼
Phase 3: Performance Data Collection（采集数据）
    ├─ $B goto <url>
    ├─ $B perf
    └─ $B eval "performance.getEntriesByType(...)"
    │
    ├─ --baseline ──→ Phase 4: Baseline Capture（保存基线）
    │                      └─ 写入 baseline.json
    │
    ▼
Phase 5: Comparison（与基线对比）
    │
    ▼
Phase 6: Slowest Resources（最慢资源分析）
    │
    ▼
Phase 7: Performance Budget（性能预算检查）
    │
    ├─ --trend ──→ Phase 8: Trend Analysis（历史趋势）
    │
    ▼
Phase 9: Save Report（保存报告）
```

### 6.2 Phase 1：初始化目录

**原文**：
```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null || echo "SLUG=unknown")"
mkdir -p .gstack/benchmark-reports
mkdir -p .gstack/benchmark-reports/baselines
```

**中文**：在项目根目录创建报告存储结构：
```
.gstack/
└── benchmark-reports/
    ├── baselines/
    │   └── baseline.json          ← 基线数据
    ├── 2026-04-07-benchmark.md    ← 本次 Markdown 报告
    └── 2026-04-07-benchmark.json  ← 本次 JSON 数据
```

### 6.3 Phase 2：页面发现

**原文**：
```bash
# --diff 模式
git diff $(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || \
  gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || \
  echo main)...HEAD --name-only
```

**中文**：`--diff` 模式的智能之处在于：只测试当前 PR **实际影响**的页面。

```
当前 PR 修改了 src/pages/dashboard.tsx
    ↓
推断受影响页面: /dashboard
    ↓
只对 /dashboard 做性能测试
    ↓
更快、更精准（不测不相关的页面）
```

> **设计原理**：全量测试所有页面可能需要几分钟。`--diff` 模式把范围缩减到受影响的页面，在 CI 中更实用——每个 PR 只测自己改动的内容。

---

## 七、性能指标体系（Phase 3）

这是 `/benchmark` 的核心，理解这些指标才能理解报告。

### 7.1 使用 `$B perf` 获取导航性能

**原文**：
```bash
$B goto <page-url>
$B perf
```

`$B perf` 是 browse daemon 的内置性能命令，直接返回浏览器测量的真实性能数据。

### 7.2 使用 `$B eval` 深度挖掘指标

**原文**：
```bash
$B eval "JSON.stringify(performance.getEntriesByType('navigation')[0])"
```

**中文**：`performance.getEntriesByType('navigation')` 返回 [Navigation Timing API](https://developer.mozilla.org/en-US/docs/Web/API/Navigation_timing_API) 数据——这是浏览器内部精确测量的时间点，比外部工具更准确。

### 7.3 六大核心时间指标详解

**原文**：
```
Extract key metrics:
- TTFB (Time to First Byte): responseStart - requestStart
- FCP (First Contentful Paint): from PerformanceObserver or paint entries
- LCP (Largest Contentful Paint): from PerformanceObserver
- DOM Interactive: domInteractive - navigationStart
- DOM Complete: domComplete - navigationStart
- Full Load: loadEventEnd - navigationStart
```

**中文**：六个指标的含义、测量方式、评估标准：

| 指标 | 全称 | 计算方式 | 含义 | Google 建议值 |
|------|------|---------|------|-------------|
| **TTFB** | Time to First Byte | `responseStart - requestStart` | 服务器响应速度 | < 800ms |
| **FCP** | First Contentful Paint | PerformanceObserver `paint` | 首次内容出现 | < 1.8s |
| **LCP** | Largest Contentful Paint | PerformanceObserver `largest-contentful-paint` | 最大内容元素加载完成 | < 2.5s |
| **DOM Interactive** | — | `domInteractive - navigationStart` | DOM 可交互时间 | — |
| **DOM Complete** | — | `domComplete - navigationStart` | DOM 完全加载 | — |
| **Full Load** | — | `loadEventEnd - navigationStart` | 页面完全加载（含所有资源） | < 3s |

### 各指标的性能含义对比

```
用户打开页面
    │
    ├─ 0ms          请求发出
    │
    ├─ TTFB         第一个字节到达（服务器响应速度的核心指标）
    │               过高 → 服务器慢、CDN 未命中、数据库查询慢
    │
    ├─ FCP          第一个内容出现（用户感知到"在加载"）
    │               过高 → CSS/JS 阻塞渲染、字体加载慢
    │
    ├─ DOM Interactive  DOM 解析完成（JS 可以操作 DOM）
    │               过高 → HTML 太大、JS 阻塞解析
    │
    ├─ LCP          最大内容加载完（用户感知"主要内容已加载"）
    │               过高 → 大图未优化、关键 JS 体积过大
    │
    ├─ DOM Complete  所有 DOM 资源加载完成
    │
    └─ Full Load    所有资源完全加载（含异步）
                    过高 → 第三方脚本、未延迟加载的资源
```

### 7.4 资源分析：最慢的 15 个资源

**原文**：
```bash
$B eval "JSON.stringify(performance.getEntriesByType('resource').map(r => ({
  name: r.name.split('/').pop().split('?')[0],
  type: r.initiatorType,
  size: r.transferSize,
  duration: Math.round(r.duration)
})).sort((a,b) => b.duration - a.duration).slice(0,15))"
```

**中文**：这条 JS 表达式：
1. 获取所有资源的性能条目（`getEntriesByType('resource')`）
2. 提取：文件名（截掉路径和查询参数）、类型、传输大小、加载时长
3. 按加载时长降序排列
4. 取最慢的 15 个

> **为什么只取文件名？** 完整 URL 太长，难以阅读。`r.name.split('/').pop().split('?')[0]` 把 `https://cdn.example.com/static/vendor.chunk.abc123.js?v=2` 变成 `vendor.chunk.abc123.js`。

### 7.5 Bundle Size 分析

**原文**：
```bash
# JS bundle 分析
$B eval "JSON.stringify(performance.getEntriesByType('resource').filter(r =>
  r.initiatorType === 'script').map(r => ({
    name: r.name.split('/').pop().split('?')[0],
    size: r.transferSize
  })))"

# CSS bundle 分析
$B eval "JSON.stringify(performance.getEntriesByType('resource').filter(r =>
  r.initiatorType === 'css').map(r => ({
    name: r.name.split('/').pop().split('?')[0],
    size: r.transferSize
  })))"
```

**中文**：分别列出所有 JS 和 CSS 文件及其传输大小（`transferSize` 是压缩后的大小，即实际网络传输量）。

### 7.6 网络概览

**原文**：
```bash
$B eval "(() => {
  const r = performance.getEntriesByType('resource');
  return JSON.stringify({
    total_requests: r.length,
    total_transfer: r.reduce((s,e) => s + (e.transferSize||0), 0),
    by_type: Object.entries(r.reduce((a,e) => {
      a[e.initiatorType] = (a[e.initiatorType]||0) + 1; return a;
    }, {})).sort((a,b) => b[1]-a[1])
  })
})()"
```

**中文**：聚合统计：总请求数、总传输量、按资源类型分组的请求数。帮助快速判断瓶颈在哪：请求数过多（HTTP 开销）、总传输量过大（内容优化）、某类型资源过多（专项优化）。

---

## 八、基线系统（Phase 4）

基线是性能回归检测的基础。没有基线，就只能看绝对数字，无法判断"是变好了还是变差了"。

### 8.1 baseline.json 格式

**原文**：
```json
{
  "url": "<url>",
  "timestamp": "<ISO>",
  "branch": "<branch>",
  "pages": {
    "/": {
      "ttfb_ms": 120,
      "fcp_ms": 450,
      "lcp_ms": 800,
      "dom_interactive_ms": 600,
      "dom_complete_ms": 1200,
      "full_load_ms": 1400,
      "total_requests": 42,
      "total_transfer_bytes": 1250000,
      "js_bundle_bytes": 450000,
      "css_bundle_bytes": 85000,
      "largest_resources": [
        {"name": "main.js", "size": 320000, "duration": 180},
        {"name": "vendor.js", "size": 130000, "duration": 90}
      ]
    }
  }
}
```

**中文**：`baseline.json` 存储在 `.gstack/benchmark-reports/baselines/baseline.json`。字段含义：

| 字段 | 单位 | 说明 |
|------|------|------|
| `url` | — | 被测试的应用 URL |
| `timestamp` | ISO 8601 | 基线建立时间 |
| `branch` | — | 基线建立时的分支（通常是 `main`） |
| `ttfb_ms` | 毫秒 | Time to First Byte |
| `fcp_ms` | 毫秒 | First Contentful Paint |
| `lcp_ms` | 毫秒 | Largest Contentful Paint |
| `total_transfer_bytes` | 字节 | 总传输量 |
| `js_bundle_bytes` | 字节 | JS 包总大小 |
| `css_bundle_bytes` | 字节 | CSS 包总大小 |
| `largest_resources` | — | 最大资源列表（name + size + duration） |

### 8.2 基线建立策略

```
最佳实践：在 main 分支建立基线

git checkout main
/benchmark https://myapp.com --baseline
→ 写入 .gstack/benchmark-reports/baselines/baseline.json

git checkout feature/new-dashboard
# 开发...
/benchmark https://myapp.com
→ 与 baseline.json 对比，输出回归报告
```

> **重要**：基线应该在**干净的 main 分支**上建立，不要在 feature 分支上建立基线。feature 分支的数据不是"标准"，与它比较毫无意义。

---

## 九、回归检测与对比报告（Phase 5）

### 9.1 完整对比报告格式

**原文**：
```
PERFORMANCE REPORT — [url]
══════════════════════════
Branch: [current-branch] vs baseline ([baseline-branch])

Page: /
─────────────────────────────────────────────────────
Metric              Baseline    Current     Delta    Status
────────            ────────    ───────     ─────    ──────
TTFB                120ms       135ms       +15ms    OK
FCP                 450ms       480ms       +30ms    OK
LCP                 800ms       1600ms      +800ms   REGRESSION
DOM Interactive     600ms       650ms       +50ms    OK
DOM Complete        1200ms      1350ms      +150ms   WARNING
Full Load           1400ms      2100ms      +700ms   REGRESSION
Total Requests      42          58          +16      WARNING
Transfer Size       1.2MB       1.8MB       +0.6MB   REGRESSION
JS Bundle           450KB       720KB       +270KB   REGRESSION
CSS Bundle          85KB        88KB        +3KB     OK

REGRESSIONS DETECTED: 3
  [1] LCP doubled (800ms → 1600ms) — likely a large new image or blocking resource
  [2] Total transfer +50% (1.2MB → 1.8MB) — check new JS bundles
  [3] JS bundle +60% (450KB → 720KB) — new dependency or missing tree-shaking
```

**中文**：报告格式清晰的设计：
- 左对齐的指标名、固定宽度的数字列
- Delta（变化量）用 `+`/`-` 明确标示方向
- Status 用 `OK`/`WARNING`/`REGRESSION` 三档区分严重程度
- 末尾汇总 REGRESSIONS，附带人类可读的诊断信息

### 9.2 回归阈值详解

**原文**：
```
Regression thresholds:
- Timing metrics: >50% increase OR >500ms absolute increase = REGRESSION
- Timing metrics: >20% increase = WARNING
- Bundle size: >25% increase = REGRESSION
- Bundle size: >10% increase = WARNING
- Request count: >30% increase = WARNING
```

**中文**：阈值表：

| 指标类型 | WARNING 阈值 | REGRESSION 阈值 | 设计理由 |
|----------|-------------|-----------------|---------|
| **时间指标** | >20% 增加 | >50% 增加 **或** >500ms 绝对增加 | 双阈值：相对阈值捕捉小基数的大变化；绝对阈值捕捉大基数的可感知劣化 |
| **包体积** | >10% 增加 | >25% 增加 | 包体积对性能影响是确定性的，阈值更严格 |
| **请求数** | >30% 增加 | — | 请求数过多影响 HTTP 连接复用，值得警告 |

### 阈值设计原理分析

```
为什么时间指标用"双阈值"？

场景 A: 基线 TTFB = 100ms, 当前 = 160ms
  相对变化: +60% → REGRESSION ✓ (抓住了问题)

场景 B: 基线 TTFB = 2000ms, 当前 = 2600ms
  相对变化: +30% → WARNING
  绝对变化: +600ms → REGRESSION ✓ (用户能感知到 600ms 的差距)

场景 C: 基线 TTFB = 5000ms, 当前 = 5200ms
  相对变化: +4% → OK
  绝对变化: +200ms → OK ✓ (200ms 在 5s 基础上感知不明显)
```

---

## 十、最慢资源分析（Phase 6）

**原文**：
```
TOP 10 SLOWEST RESOURCES
═════════════════════════
#   Resource                  Type      Size      Duration
1   vendor.chunk.js          script    320KB     480ms
2   main.js                  script    250KB     320ms
3   hero-image.webp          img       180KB     280ms
4   analytics.js             script    45KB      250ms    ← third-party
5   fonts/inter-var.woff2    font      95KB      180ms
...

RECOMMENDATIONS:
- vendor.chunk.js: Consider code-splitting — 320KB is large for initial load
- analytics.js: Load async/defer — blocks rendering for 250ms
- hero-image.webp: Add width/height to prevent CLS, consider lazy loading
```

**中文**：最慢资源分析的核心价值：**找到性能瓶颈的具体元凶**。

报告中的每条建议都对应具体的优化动作：

| 资源类型 | 常见问题 | 推荐优化 |
|----------|---------|---------|
| `vendor.chunk.js` 过大 | 依赖包未分割 | Code splitting / Dynamic import |
| `analytics.js` 阻塞 | 第三方脚本同步加载 | `async` 或 `defer` 属性 |
| `hero-image.webp` 无尺寸 | 缺少 width/height 导致 CLS | 明确图片尺寸 + lazy loading |
| `inter-var.woff2` 字体慢 | 字体文件大 | `font-display: swap` + 预加载 |

> **设计原理：为什么标注第三方资源（← third-party）？**
> 原文：`Third-party scripts are context. Flag them, but the user can't fix Google Analytics being slow. Focus recommendations on first-party resources.`
>
> 中文：第三方脚本慢是"上下文"——你控制不了 Google Analytics 的速度。标注它们是为了**排除干扰项**，让用户专注在自己可以优化的资源上。

---

## 十一、性能预算检查（Phase 7）

**原文**：
```
PERFORMANCE BUDGET CHECK
════════════════════════
Metric              Budget      Actual      Status
────────            ──────      ──────      ──────
FCP                 < 1.8s      0.48s       PASS
LCP                 < 2.5s      1.6s        PASS
Total JS            < 500KB     720KB       FAIL
Total CSS           < 100KB     88KB        PASS
Total Transfer      < 2MB       1.8MB       WARNING (90%)
HTTP Requests       < 50        58          FAIL

Grade: B (4/6 passing)
```

**中文**：性能预算是基于**行业标准**的绝对阈值检查（而 Phase 5 的对比是相对基线的检查）。

### 内置行业标准预算

| 指标 | 预算（上限） | 标准来源 |
|------|------------|---------|
| FCP | < 1.8s | Google Core Web Vitals "Good" |
| LCP | < 2.5s | Google Core Web Vitals "Good" |
| Total JS | < 500KB | 行业共识 |
| Total CSS | < 100KB | 行业共识 |
| Total Transfer | < 2MB | 移动网络友好 |
| HTTP Requests | < 50 | HTTP/2 最佳实践 |

### 两种阈值系统的区别

```
Phase 5（基线对比）: 你的性能是否比之前变差了？
                      → 相对检测，发现回归
                      → "LCP 增加了 100%" → REGRESSION

Phase 7（预算检查）: 你的性能是否达到行业标准？
                      → 绝对检测，评估当前水准
                      → "LCP = 2.8s > 2.5s" → FAIL
```

> **设计原理**：两套检查互补，缺一不可。  
> 只有基线对比：可能在"差"的基线上没有退化，但整体性能仍然很糟糕。  
> 只有预算检查：可能今天达标，但 JS 每周增长 50KB，一个月后就会超标。

---

## 十二、历史趋势分析（Phase 8）

**原文**：
```
PERFORMANCE TRENDS (last 5 benchmarks)
══════════════════════════════════════
Date        FCP     LCP     Bundle    Requests    Grade
2026-03-10  420ms   750ms   380KB     38          A
2026-03-12  440ms   780ms   410KB     40          A
2026-03-14  450ms   800ms   450KB     42          A
2026-03-16  460ms   850ms   520KB     48          B
2026-03-18  480ms   1600ms  720KB     58          B

TREND: Performance degrading. LCP doubled in 8 days.
       JS bundle growing 50KB/week. Investigate.
```

**中文**：趋势分析的价值是**预测性**：在 Phase 5 的回归检测之外，额外提供"这个方向是否可持续"的判断。

从上面的示例数据可以看出：
- LCP 在 2026-03-16 → 2026-03-18 发生了突变（850ms → 1600ms），可定位到具体 PR
- JS bundle 从 380KB 增长到 720KB，两周涨了 89%——如果按这个速度，一个月后就超 1MB

> **设计原理**：单次回归检测是局部的（这次 PR 有没有问题），趋势分析是全局的（这个项目的方向对不对）。两者结合，才能既抓具体 Bug 又管整体方向。

---

## 十三、报告保存（Phase 9）

**原文**：
```
Write to `.gstack/benchmark-reports/{date}-benchmark.md` and
`.gstack/benchmark-reports/{date}-benchmark.json`.
```

**中文**：每次运行生成两个文件：

```
.gstack/benchmark-reports/
├── baselines/
│   └── baseline.json              ← 持久化基线（--baseline 时写入）
├── 2026-04-07-benchmark.md        ← 人类可读报告
└── 2026-04-07-benchmark.json      ← 机器可读数据（用于趋势分析）
```

`.json` 格式让 `--trend` 模式可以跨时间聚合数据。`.md` 格式方便在 PR 评论中直接粘贴。

---

## 十四、重要规则（Important Rules）

**原文**：
```
- Measure, don't guess. Use actual performance.getEntries() data, not estimates.
- Baseline is essential. Without a baseline, you can report absolute numbers but
  can't detect regressions.
- Relative thresholds, not absolute. 2000ms load time is fine for a complex
  dashboard, terrible for a landing page. Compare against YOUR baseline.
- Third-party scripts are context. Flag them, but focus on first-party resources.
- Bundle size is the leading indicator. Load time varies with network. Bundle
  size is deterministic. Track it religiously.
- Read-only. Produce the report. Don't modify code unless explicitly asked.
```

**中文**：六条核心规则解析：

### 规则 1：测量，不猜测

```bash
# 错误做法：估算
"这个页面大概要 2 秒加载"

# 正确做法：测量
$B perf
→ {"ttfb": 135, "fcp": 480, "lcp": 1600, ...}
```

`performance.getEntriesByType()` 是浏览器内核的精确测量，不是估算。

### 规则 2：基线是关键

```
没有基线时：
  "LCP = 1600ms" — 好还是不好？不知道。

有基线时：
  "LCP: 800ms → 1600ms (+100%)" — REGRESSION！清楚。
```

没有基线，就无法判断回归，只能报告绝对数字，价值大打折扣。

### 规则 3：相对阈值，不是绝对阈值

```
复杂仪表盘: LCP = 2800ms → 可以接受（功能丰富）
落地页:     LCP = 2800ms → 不可接受（应该 < 1s）
```

`/benchmark` 的阈值系统基于**你自己的基线**，不是固定标准——这比 Lighthouse 的固定分数更实用。

### 规则 4：第三方脚本是上下文

标注第三方资源（如 Google Analytics、Intercom、Hotjar），但建议专注于第一方资源的优化。你无法让 Google 的服务器变快。

### 规则 5：Bundle Size 是领先指标

```
加载时间    = f(包体积, 网络速度, 服务器速度, CDN, 用户设备, ...)
                 ↑
           这个是你能控制的

在不同网络环境下，加载时间差异可以是 10x。
但 JS bundle 是 500KB，无论什么网络都是 500KB。
```

**Bundle size 是唯一可预测的性能指标**，优先追踪它。

### 规则 6：只读不改

```
/benchmark 的输出:  报告、分析、建议
/benchmark 不做的:  修改代码、修改配置、自动优化

用户决定: 要不要按建议优化
           → 优化后再次运行 /benchmark 验证
```

---

## 十五、Operational Self-Improvement（操作自改进）

**原文**：
```
Before completing, reflect on this session:
- Did any commands fail unexpectedly?
- Did you discover a project-specific quirk?

If yes, log an operational learning:
gstack-learnings-log '{"skill":"benchmark","type":"operational",...}'
```

**中文**：性能测试领域特有的项目知识值得记录：

```json
{"skill":"benchmark","type":"operational",
 "key":"health-check-delay",
 "insight":"这个项目的 /api/health 需要 warm-up，冷启动时 TTFB 约 2s，不代表真实性能",
 "confidence":8,"source":"observed"}

{"skill":"benchmark","type":"operational",
 "key":"baseline-branch",
 "insight":"baseline 要在 main 分支建立，feature 分支有临时代码会干扰数据",
 "confidence":9,"source":"observed"}
```

---

## 十六、与 CI/CD 集成的典型模式

### 模式 A：PR 性能门控

```yaml
# .github/workflows/benchmark.yml
name: Performance Check
on: [pull_request]
jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run benchmark
        run: |
          # 假设 baseline 已在 main 分支提交
          /benchmark https://staging.myapp.com
          # 如有 REGRESSION，退出码非 0，阻断 PR 合并
```

### 模式 B：定期趋势追踪

```yaml
# 每周一自动建立新基线
on:
  schedule:
    - cron: '0 9 * * 1'  # 每周一 9:00
jobs:
  baseline:
    steps:
      - run: /benchmark https://myapp.com --baseline
      - run: git add .gstack/benchmark-reports && git commit -m "chore: update benchmark baseline"
```

### 模式 C：发布前完整审计

```
发布流程:
1. /ship (创建 PR)
2. /benchmark https://staging.myapp.com (性能对比)
3. 确认无 REGRESSION
4. /land-and-deploy (合并+上线)
5. /canary (上线后监控)
```

---

## 十七、与其他技能的深度对比

### `/benchmark` vs `/canary`

| 维度 | `/benchmark` | `/canary` |
|------|-------------|----------|
| **目的** | 性能回归检测 | 部署后健康监控 |
| **时机** | PR 合并**前** | 部署**后** |
| **频率** | 按需/每 PR | 持续/定期 |
| **关注点** | 性能指标、包体积 | 错误率、页面可访问性 |
| **产出** | 回归报告 + 建议 | 健康告警 |
| **基线** | 必须有基线才能检测回归 | 不需要基线 |

### `/benchmark` vs `/qa`

| 维度 | `/benchmark` | `/qa` |
|------|-------------|-------|
| **目的** | 性能是否退化 | 功能是否正确 |
| **测试对象** | 页面加载时间、资源大小 | 用户交互、业务逻辑 |
| **关注点** | "快不快" | "对不对" |
| **数据来源** | `performance.getEntries()` | 页面交互、DOM 状态 |
| **产出** | 性能报告 + 回归标记 | Bug 列表 + 截图 |

### 三技能协作模式

```
功能开发完成
    │
    ├──→ /qa          → 功能测试（对不对？）
    ├──→ /benchmark   → 性能测试（快不快？）
    │
    都通过
    │
    ▼
/land-and-deploy      → 合并并部署
    │
    ▼
/canary               → 上线监控（还健康吗？）
```

---

## 十八、关键设计哲学小结

| 设计原则 | 体现方式 |
|----------|----------|
| **只读原则** | 只生成报告，不修改代码 |
| **测量优于估算** | 使用 `performance.getEntriesByType()` 获取真实数据 |
| **相对比绝对更有用** | 与自己的基线比，不与固定标准比 |
| **领先指标优先** | Bundle size 是最可预测的指标，优先追踪 |
| **分层告警** | OK / WARNING / REGRESSION 三档，避免噪音 |
| **趋势比快照更有价值** | `--trend` 模式揭示长期方向 |
| **聚焦可控资源** | 区分第一方/第三方，专注可优化的部分 |
| **双重验证体系** | 基线对比（回归）+ 行业预算（绝对水准）互补 |

---

## 附录：性能指标速查表

### Navigation Timing API 字段映射

```
                          navigationStart (0)
                               │
             ┌─────────────────┤
             ▼                 │
        redirectStart          │
        redirectEnd            │
             │                 │
        fetchStart            ─┤
             │                 │
        domainLookupStart      │
        domainLookupEnd        │
             │                 │
        connectStart           │
        connectEnd             │   ← TTFB = responseStart - requestStart
             │                 │
        requestStart ──────────┤
        responseStart          │   ← TTFB 结束点
        responseEnd            │
             │                 │
        domInteractive ────────┤   ← DOM Interactive
        domContentLoadedEnd    │
        domComplete ───────────┤   ← DOM Complete
             │                 │
        loadEventStart         │
        loadEventEnd ──────────┘   ← Full Load
```

### Bundle Size 规模参考

| 大小 | 评级 | 说明 |
|------|------|------|
| JS < 200KB | 优秀 | 快速加载 |
| JS 200-500KB | 良好 | 可接受 |
| JS 500KB-1MB | 警告 | 考虑分割 |
| JS > 1MB | 危险 | 严重影响加载 |
| CSS < 50KB | 优秀 | — |
| CSS 50-100KB | 良好 | — |
| CSS > 100KB | 警告 | 考虑提取关键 CSS |
