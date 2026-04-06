# 技能模板编译管线深度解读

> 对应源码：[`scripts/gen-skill-docs.ts`](https://github.com/garrytan/gstack/blob/main/scripts/gen-skill-docs.ts) + [`scripts/resolvers/`](https://github.com/garrytan/gstack/tree/main/scripts/resolvers) + [`hosts/`](https://github.com/garrytan/gstack/tree/main/hosts)
> .tmpl 文件如何变成 9 个 AI 平台的 SKILL.md。

---

## 架构概览

gstack 的技能不只服务 Claude——同一套 `.tmpl` 模板生成 9 个 AI 平台的 SKILL.md。

```
                    ┌─────────────────┐
                    │  .tmpl 模板文件  │
                    │ (单一真相源)     │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ gen-skill-docs  │
                    │   (658 行)      │
                    │                 │
                    │ 1. 读模板       │
                    │ 2. 提取元数据   │
                    │ 3. 解析占位符   │
                    │ 4. 调用 resolver│
                    │ 5. 转换 frontmatter│
                    │ 6. 宿主适配     │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
      ┌──────────┐    ┌──────────┐    ┌──────────┐
      │  Claude   │    │  Codex   │    │ 7 other  │
      │ SKILL.md  │    │ SKILL.md │    │ hosts    │
      │ (原始路径)│    │ + yaml   │    │          │
      └──────────┘    └──────────┘    └──────────┘
```

---

## 9 个 AI 宿主

| 宿主 | 目录 | Frontmatter | 特殊处理 |
|------|------|-------------|---------|
| **Claude** | `skill/SKILL.md` | denylist（去掉 sensitive/voice-triggers） | 主宿主，无 env vars |
| **Codex** | `.agents/skills/` | allowlist（name+desc），1024 字符限 | 生成 openai.yaml |
| **Factory** | `.factory/skills/` | allowlist + conditional | 工具重写（Bash→"run"） |
| **Cursor** | `.cursor/skills/` | allowlist | 跳过 codex 技能 |
| **OpenCode** | `.opencode/skills/` | allowlist | 跳过 codex 技能 |
| **Slate** | `.slate/skills/` | allowlist | — |
| **Kiro** | `.kiro/skills/` | allowlist | — |
| **OpenClaw** | `.openclaw/skills/` | allowlist + version | 后处理适配器 |

---

## 模板变量解析

模板里的 `{{PLACEHOLDER}}` 由 resolver 函数处理：

```
{{PREAMBLE}}           → resolvers/preamble.ts    (739 行，4 级)
{{BROWSE_SETUP}}       → resolvers/browse.ts      (检测 browse 二进制)
{{LEARNINGS_SEARCH}}   → resolvers/learnings.ts   (搜索历史学习记录)
{{TEST_COVERAGE_AUDIT_PLAN}} → resolvers/testing.ts (测试覆盖率审计)
{{CONFIDENCE_CALIBRATION}}   → resolvers/confidence.ts (置信度校准)
{{CODEX_PLAN_REVIEW}}  → resolvers/review.ts      (Codex 评审)
{{REVIEW_DASHBOARD}}   → resolvers/review.ts      (评审看板)
{{REVIEW_ARMY}}        → resolvers/review-army.ts  (专项评审军团)
{{BASE_BRANCH_DETECT}} → resolvers/utility.ts     (检测 main/master)
{{CO_AUTHOR_TRAILER}}  → resolvers/utility.ts     (Git co-author)
...共 25+ 个 resolver
```

**参数化调用**：
```
{{INVOKE_SKILL:plan-ceo-review:skip=Outside Voice}}
  → 读取另一个技能的 SKILL.md，跳过指定章节
```

**宿主抑制**：
```
Codex 的 suppressedResolvers: [
  'CODEX_PLAN_REVIEW',      // 不让 Codex 评审自己
  'CODEX_SECOND_OPINION',
  'ADVERSARIAL_STEP',
  'REVIEW_ARMY'
]
```

---

## Preamble 分级系统

最复杂的 resolver，739 行，分 4 个层级：

| 级别 | 包含内容 | 使用技能 |
|------|---------|---------|
| **T1** | bash setup + 升级检查 + telemetry + 简短语音指令 | browse, benchmark |
| **T2** | + 完整语音指令 + AskUserQuestion 格式 + 完整性原则 + 上下文恢复 | investigate, cso, retro |
| **T3** | + repo 模式检测 + Search Before Building | office-hours, plan-*-review, autoplan |
| **T4** | + 测试失败归因（Test Failure Triage） | ship, review, qa, design-review |

每个级别包含前一级的所有内容。T4 = 最完整。

---

## Frontmatter 转换

**Claude（denylist 模式）**：
```yaml
# 模板里的：
sensitive: true
voice-triggers: ["ship it"]

# 生成后被去掉（Claude 不需要这些字段）
```

**外部宿主（allowlist 模式）**：
```yaml
# 只保留 name + description
# description 可能被截断到 1024 字符
# 可注入额外字段：
#   user-invocable: true（Factory）
#   disable-model-invocation: true（条件注入）
```

---

## 路径重写 + 工具重写

**路径**（外部宿主不知道 `~/.claude/`）：
```
~/.claude/skills/gstack  →  $GSTACK_ROOT
.claude/skills           →  .agents/skills
```

**工具**（不同平台的 API 不同）：
```
Factory:
  "use the Bash tool"   →  "run this command"
  "use the Agent tool"  →  "dispatch subagent"

OpenClaw:
  "Bash"   →  "exec"
  "Agent"  →  "sessions_spawn"
```

---

## OpenClaw 特殊处理

OpenClaw 是编排器（不是 AI 平台），需要额外生成 3 个"纪律指南"：

```
gstack-lite-CLAUDE.md  → 规划纪律（读文件→规划→评审→完成）
gstack-full-CLAUDE.md  → 完整流程（规划→autoplan→实现→ship→报告）
gstack-plan-CLAUDE.md  → 纯规划（读→设计文档→autoplan→保存→报告）
```

还有后处理适配器（`openclaw-adapter.ts`）做语义级转换。

---

## DX 工具

### skill-check.ts（健康仪表盘）

```bash
bun run skill:check
```

检查所有 SKILL.md：
- 命令验证（$B 命令是否有效）
- 模板覆盖（哪些有 .tmpl 源）
- 外部宿主生成状态
- 新鲜度检查（`--dry-run` 对比）

### dev-skill.ts（开发模式）

```bash
bun run dev:skill
```

监听 `.tmpl` + `commands.ts` + `snapshot.ts`，
变更时自动重新生成所有 SKILL.md 并验证。

---

## 完整管线流程

```
1. 读 .tmpl 文件
2. 提取 YAML frontmatter（name, description, preamble-tier, benefits-from, allowed-tools）
3. 构建 TemplateContext（技能元数据 + 宿主信息 + 路径）
4. 正则匹配 {{PLACEHOLDER}} 或 {{PLACEHOLDER:arg1:arg2}}
5. 查找 RESOLVERS 映射
   └─ 宿主抑制？→ 返回空字符串
   └─ 否则调用 resolver(ctx, args)
6. 处理 voice-triggers（折叠到 description，删除字段）
7. 转换 frontmatter
   ├─ Claude: denylist（去掉 sensitive/voice-triggers）
   └─ 外部: allowlist + 条件字段注入 + description 限长
8. 外部宿主额外处理：
   ├─ 路径重写
   ├─ 工具重写
   ├─ 元数据生成（Codex: openai.yaml）
   └─ 适配器（OpenClaw: 语义转换）
9. 添加自动生成头部标记
10. 输出到对应目录
```

---

## 设计决策总结

| 决策 | 原因 |
|------|------|
| 单一 .tmpl 源 | 一处修改，9 个平台同步 |
| Config-driven 宿主 | 添加新宿主只需一个 .ts 文件 |
| Resolver 模式 | 各领域解耦（测试/设计/评审/浏览器） |
| 宿主抑制 | Codex 不评审自己 |
| Preamble 分级 | 不同技能需要不同深度的上下文 |
| 路径/工具重写 | 平台间的 API 差异适配 |
| --dry-run | CI 新鲜度检查 |
