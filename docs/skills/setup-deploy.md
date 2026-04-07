# `/setup-deploy` 技能逐段中英对照注解

> 对应源文件：[`setup-deploy/SKILL.md`](https://github.com/garrytan/gstack/blob/main/setup-deploy/SKILL.md)（735 行）
> 本文**逐段**保留英文原文，加入中文翻译和设计原理解读。不是摘要——是完整的注解版。

---

## 一、技能定位与核心价值

`/setup-deploy` 是 gstack 部署工作流的**前置配置技能**。它的定位非常明确：**一次运行，永久有效**。

```
/setup-deploy → 写入 CLAUDE.md
                    ↓
           /land-and-deploy 读取 CLAUDE.md
                    ↓
              自动完成部署（无需再次检测）
```

没有 `/setup-deploy`，每次运行 `/land-and-deploy` 都要重新做平台检测、询问 URL、确认健康检查——效率极低。有了它，配置持久化到 `CLAUDE.md`，后续部署全自动。

### 与其他技能的关系

```
/office-hours ──→ /ship ──→ /setup-deploy ──→ /land-and-deploy
（构思）          （PR）     （配置部署）        （合并+验证）
```

| 技能 | 职责 | 运行时机 |
|------|------|----------|
| `/ship` | 创建 PR，推送分支 | 功能完成后 |
| `/setup-deploy` | 配置部署环境 | **首次部署前（一次性）** |
| `/land-and-deploy` | 合并 PR，触发部署，验证上线 | 每次合并时 |
| `/canary` | 持续监控部署后的健康状态 | 部署后 |

---

## 二、Frontmatter（元数据区）

```yaml
---
name: setup-deploy
preamble-tier: 2
version: 1.0.0
description: |
  Configure deployment settings for /land-and-deploy. Detects your deploy
  platform (Fly.io, Render, Vercel, Netlify, Heroku, GitHub Actions, custom),
  production URL, health check endpoints, and deploy status commands. Writes
  the configuration to CLAUDE.md so all future deploys are automatic.
  Use when: "setup deploy", "configure deployment", "set up land-and-deploy",
  "how do I deploy with gstack", "add deploy config".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---
```

**中文翻译**：

- **name**: 技能名称。用户输入 `/setup-deploy` 触发。
- **preamble-tier: 2**: Preamble 详细度级别 2（共 4 级）。包含会话追踪、版本检查、学习系统等核心机制，但略过部分高级功能（如 Search Before Building）。
- **description**: 为 `/land-and-deploy` 配置部署设置。检测部署平台（Fly.io、Render、Vercel、Netlify、Heroku、GitHub Actions、自定义），生产 URL，健康检查端点，部署状态命令。将配置写入 CLAUDE.md，让后续所有部署自动化。
- **allowed-tools**: 注意这里**有 Edit 和 Write**——需要修改 `CLAUDE.md`。也有 `AskUserQuestion`——配置过程是交互式的。

> **设计原理：为什么需要 Edit 权限？**
> 这个技能的核心产出是写入配置文件。写入 CLAUDE.md 是它存在的意义——没有写入权限就无法完成任务。与之对比，`/plan-eng-review` 没有 Edit 权限，因为评审技能不应修改项目代码。

---

## 三、Preamble（前置运行区）

Preamble 是每个 gstack 技能启动时必须运行的标准化初始化代码块，在 `SKILL.md` 的第 24-98 行。Tier 2 包含以下关键部分：

### 3.1 版本检查与会话管理

```bash
_UPD=$(~/.claude/skills/gstack/bin/gstack-update-check 2>/dev/null || .claude/skills/gstack/bin/gstack-update-check 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD" || true
mkdir -p ~/.gstack/sessions
touch ~/.gstack/sessions/"$PPID"
_SESSIONS=$(find ~/.gstack/sessions -mmin -120 -type f 2>/dev/null | wc -l | tr -d ' ')
find ~/.gstack/sessions -mmin +120 -type f -exec rm {} + 2>/dev/null || true
```

**中文**：检查 gstack 是否有新版本。用 `$PPID`（父进程 ID）作为会话标识符，在 `~/.gstack/sessions/` 目录记录活跃会话。超过 120 分钟的会话自动清理。

> **设计原理：为什么用 PPID？**  
> Claude 的每次会话都有独立的父进程。用 PPID 作为会话 ID，可以：  
> 1. 区分多个同时运行的 Claude 实例  
> 2. 检测用户是否在多个窗口中运行 gstack  
> 3. 记录会话时长（start 到 end 的时间差）

### 3.2 分支检测与配置读取

```bash
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
_SKILL_PREFIX=$(~/.claude/skills/gstack/bin/gstack-config get skill_prefix 2>/dev/null || echo "false")
echo "PROACTIVE: $_PROACTIVE"
source <(~/.claude/skills/gstack/bin/gstack-repo-mode 2>/dev/null) || true
REPO_MODE=${REPO_MODE:-unknown}
echo "REPO_MODE: $REPO_MODE"
```

**中文**：读取当前 git 分支名，检测是否启用技能前缀模式（`/gstack-` vs `/`），检测仓库模式（团队模式/个人模式）。这些信息会影响后续的提示格式和技能调用方式。

### 3.3 遥测数据记录

```bash
if [ "$_TEL" != "off" ]; then
echo '{"skill":"setup-deploy","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","repo":"'$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")'"}'  >> ~/.gstack/analytics/skill-usage.jsonl 2>/dev/null || true
fi
```

**中文**：如果用户开启了遥测，记录技能名称、时间戳、仓库名（非路径）到本地 JSONL 文件。注意：只记录仓库**名称**，不记录完整路径，也不记录代码内容。

### 3.4 学习系统检索

```bash
_LEARN_FILE="${GSTACK_HOME:-$HOME/.gstack}/projects/${SLUG:-unknown}/learnings.jsonl"
if [ -f "$_LEARN_FILE" ]; then
  _LEARN_COUNT=$(wc -l < "$_LEARN_FILE" 2>/dev/null | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT entries loaded"
  if [ "$_LEARN_COUNT" -gt 5 ] 2>/dev/null; then
    ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 3 2>/dev/null || true
  fi
fi
```

**中文**：从当前项目的学习记录（`learnings.jsonl`）中检索最相关的 3 条。这是 gstack 的**跨会话记忆机制**——如果上次部署时发现"这个项目的健康检查需要等待 30 秒才响应"，这条知识会在今天的会话中自动注入。

### 3.5 Preamble 后置行为规则

**原文（节选）**：
```
If `PROACTIVE` is `"false"`, do not proactively suggest gstack skills AND do not
auto-invoke skills based on conversation context. Only run skills the user explicitly
types (e.g., /qa, /ship).
```

**中文**：如果用户禁用了主动模式，不要自动建议或调用技能。这尊重了用户的工作流偏好——有些开发者不想被 AI 打断，只想在需要时手动调用。

---

## 四、首次使用引导系统

Preamble 中包含三个一次性引导流程，设计非常精妙：

### 4.1 Boil the Lake（完整性原则）首次介绍

**原文**：
```
If `LAKE_INTRO` is `no`: Before continuing, introduce the Completeness Principle.
Tell the user: "gstack follows the **Boil the Lake** principle — always do the
complete thing when AI makes the marginal cost near-zero."
```

**中文**：首次运行时，介绍 gstack 的核心哲学——"烧干湖"原则。当 AI 使完整实现的边际成本趋近于零时，永远选择完整方案而非捷径。一次介绍，标记后不再重复。

> **设计原理**：用 `~/.gstack/.completeness-intro-seen` 标记文件控制"只显示一次"——这是一个常见的 Unix 约定，用触摸文件代替数据库记录，零依赖，零复杂度。

### 4.2 遥测选择（三级选项）

**原文**：
```
Options:
- A) Help gstack get better! (recommended)
- B) No thanks

If B: ask a follow-up AskUserQuestion:
> How about anonymous mode? We just learn that *someone* used gstack...
```

**中文**：遥测分为三级：
| 级别 | 内容 | 标识符 |
|------|------|--------|
| Community | 技能使用情况 + 稳定设备 ID | `community` |
| Anonymous | 仅计数，无设备 ID | `anonymous` |
| Off | 完全关闭 | `off` |

> **设计原理**：两次 AskUserQuestion 的递进设计给了用户三个真实的选择，避免了简单的"开/关"二元逼迫。大多数用户在第一轮拒绝后，会在第二轮接受匿名模式——这是合理的妥协。

### 4.3 主动模式选择

**原文**：
```
> gstack can proactively figure out when you might need a skill while you work —
> like suggesting /qa when you say "does this work?" or /investigate when you hit a bug.
```

**中文**：是否让 gstack 主动识别场景并建议技能。推荐开启——这相当于有个助手在旁边随时提醒你"嘿，这个问题用 /investigate 更合适"。

---

## 五、CLAUDE.md 路由规则注入

**原文**：
```
If `HAS_ROUTING` is `no` AND `ROUTING_DECLINED` is `false` AND `PROACTIVE_PROMPTED` is `yes`:
...append this section to the end of CLAUDE.md:

## Skill routing
When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
```

**中文**：检测 `CLAUDE.md` 是否已有技能路由规则。如果没有，提议自动添加。这个路由规则告诉 Claude：遇到特定请求时，优先调用专门技能，而非直接回答。

### 路由规则对照表

| 触发场景 | 对应技能 |
|----------|----------|
| 产品想法、是否值得做、头脑风暴 | `/office-hours` |
| Bug、报错、500 错误 | `/investigate` |
| 发布、部署、创建 PR | `/ship` |
| QA 测试、找 Bug | `/qa` |
| 代码审查、检查 diff | `/review` |
| 发布后更新文档 | `/document-release` |
| 周度回顾 | `/retro` |
| 设计系统、品牌 | `/design-consultation` |
| 视觉审查、设计优化 | `/design-review` |
| 架构评审 | `/plan-eng-review` |
| 保存进度、检查点 | `/checkpoint` |
| 代码质量、健康检查 | `/health` |

> **设计原理**：这个路由规则是 gstack 的核心——它把 Claude 从一个"通用助手"升级为"专业工作流编排器"。没有这些规则，用户每次都需要手动输入 `/ship`；有了它，说"帮我发布"就够了。

---

## 六、Context Recovery（会话恢复）

**原文**：
```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
_PROJ="${GSTACK_HOME:-$HOME/.gstack}/projects/${SLUG:-unknown}"
if [ -d "$_PROJ" ]; then
  echo "--- RECENT ARTIFACTS ---"
  find "$_PROJ/ceo-plans" "$_PROJ/checkpoints" -type f -name "*.md" 2>/dev/null | xargs ls -t 2>/dev/null | head -3
  [ -f "$_PROJ/${_BRANCH}-reviews.jsonl" ] && echo "REVIEWS: $(wc -l < ...) entries"
  [ -f "$_PROJ/timeline.jsonl" ] && tail -5 "$_PROJ/timeline.jsonl"
fi
```

**中文**：Claude 的上下文窗口有限。当会话压缩（compaction）发生后，通过读取本地存储的制品（计划文档、检查点、审查记录、时间线），重建上下文。这让 AI 能在"失忆"后快速恢复状态。

```
会话开始/恢复
    ↓
检查 ~/.gstack/projects/{slug}/
    ↓
发现最近制品 → 读取 → 重建上下文
    ↓
"Welcome back to {branch}. Last session: /{skill} ({outcome})."
```

---

## 七、AskUserQuestion 格式规范

**原文**：
```
ALWAYS follow this structure for every AskUserQuestion call:
1. Re-ground: State the project, the current branch...
2. Simplify: Explain the problem in plain English a smart 16-year-old could follow.
3. Recommend: RECOMMENDATION: Choose [X] because [one-line reason]
4. Options: Lettered options: A) ... B) ... C) ...
```

**中文**：每次交互式提问必须遵循四步结构：

| 步骤 | 目的 | 示例 |
|------|------|------|
| Re-ground | 重新定位上下文 | "项目 myapp，当前分支 feature/deploy" |
| Simplify | 用简单语言解释问题 | "我需要知道你的 app 运行在哪里" |
| Recommend | 给出有立场的建议 | "RECOMMENDATION: 选 A，因为 Fly.io 有完整 CLI 支持" |
| Options | 字母选项 | "A) Fly.io  B) Render  C) 自定义" |

> **Completeness 评分（10分制）**：10 = 完整实现（含所有边界情况），7 = 覆盖主流程，3 = 捷径方案。推荐 ≥8 分的选项。

---

## 八、核心工作流：`/setup-deploy` 的六步流程

这是技能的核心部分，位于源文件第 538-735 行。

### 8.1 整体流程图

```
/setup-deploy
    │
    ▼
Step 1: 检查现有配置
    │
    ├─ 已有配置 ──→ 展示 → 询问：更新/部分修改/保持不变
    │
    └─ 无配置 ──→ Step 2: 平台自动检测
                      │
                      ▼
              Step 3: 平台专项配置
                      │
                      ▼
              Step 4: 写入 CLAUDE.md
                      │
                      ▼
              Step 5: 验证（curl + CLI 命令）
                      │
                      ▼
              Step 6: 输出摘要
```

### 8.2 Step 1：检查现有配置（幂等性保证）

**原文**：
```bash
grep -A 20 "## Deploy Configuration" CLAUDE.md 2>/dev/null || echo "NO_CONFIG"
```

如果配置已存在，展示并询问：
- A) 从头重新配置（覆盖现有）
- B) 修改特定字段
- C) 完成——配置看起来正确

**中文**：幂等性是这个技能的关键设计原则。**重复运行不会破坏现有配置**，而是先检测、再询问。用户选 C 直接退出，零副作用。

> **设计原理**：很多配置工具的问题是"破坏性运行"——再次运行就覆盖一切。gstack 的做法是先读取、展示、征求同意，然后才写入。这让重复运行变得安全。

### 8.3 Step 2：平台自动检测

**原文**：
```bash
# Platform config files
[ -f fly.toml ] && echo "PLATFORM:fly" && cat fly.toml
[ -f render.yaml ] && echo "PLATFORM:render" && cat render.yaml
[ -f vercel.json ] || [ -d .vercel ] && echo "PLATFORM:vercel"
[ -f netlify.toml ] && echo "PLATFORM:netlify" && cat netlify.toml
[ -f Procfile ] && echo "PLATFORM:heroku"
[ -f railway.json ] || [ -f railway.toml ] && echo "PLATFORM:railway"

# GitHub Actions deploy workflows
for f in $(find .github/workflows -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null); do
  [ -f "$f" ] && grep -qiE "deploy|release|production|staging|cd" "$f" 2>/dev/null && echo "DEPLOY_WORKFLOW:$f"
done

# Project type
[ -f package.json ] && grep -q '"bin"' package.json 2>/dev/null && echo "PROJECT_TYPE:cli"
find . -maxdepth 1 -name '*.gemspec' 2>/dev/null | grep -q . && echo "PROJECT_TYPE:library"
```

**中文**：平台检测通过**特征文件**识别，不需要用户手动输入平台名称。

### 平台识别特征文件对照表

| 平台 | 特征文件/目录 | 补充检测 |
|------|-------------|---------|
| **Fly.io** | `fly.toml` | `fly` CLI + `fly status` |
| **Render** | `render.yaml` | `$RENDER_API_KEY` 环境变量 |
| **Vercel** | `vercel.json` 或 `.vercel/` 目录 | `vercel` CLI + `vercel ls` |
| **Netlify** | `netlify.toml` | 站点 URL |
| **Heroku** | `Procfile` | — |
| **Railway** | `railway.json` 或 `railway.toml` | — |
| **GitHub Actions** | `.github/workflows/*.yml`（含 deploy/cd 关键词） | 读取 workflow 内容 |
| **项目类型: CLI** | `package.json` 中含 `"bin"` | 无 URL |
| **项目类型: Library** | `*.gemspec` 文件 | 无 URL |

> **设计原理**：优先从文件系统推断，避免打扰用户。绝大多数项目只有一个配置文件，检测准确率接近 100%。只有在完全无法检测时，才进入 Custom/Manual 流程。

### 8.4 Step 3：各平台专项配置

#### Fly.io 配置流程

**原文**：
```
1. Extract app name: grep -m1 "^app" fly.toml | sed 's/app = "\(.*\)"/\1/'
2. Check if `fly` CLI is installed: which fly 2>/dev/null
3. If installed, verify: fly status --app {app} 2>/dev/null
4. Infer URL: https://{app}.fly.dev
5. Set deploy status command: fly status --app {app}
6. Set health check: https://{app}.fly.dev (or /health if the app has one)
```

**中文**：Fly.io 是 gstack 支持最完整的平台。从 `fly.toml` 提取应用名 → 推断 URL `{app}.fly.dev` → 用 `fly status` 检查健康状态。注意：有些 Fly 应用用自定义域名，需要用户确认。

```
fly.toml
    ↓ 提取 app 名称
https://{app}.fly.dev     ← 推断生产 URL
    ↓
fly status --app {app}    ← 部署状态检查命令
    ↓
GET https://{app}.fly.dev/health  ← 健康检查端点
```

#### Render 配置流程

**原文**：
```
4. Render deploys automatically on push to the connected branch — no deploy workflow needed
5. The "deploy wait" in /land-and-deploy should poll the Render URL until it responds
   with the new version.
```

**中文**：Render 是纯 GitOps 平台——合并到主分支后自动触发部署，无需手动命令。`/land-and-deploy` 会持续轮询生产 URL，直到新版本响应为止。

#### Vercel 配置流程

**原文**：
```
3. Vercel deploys automatically on push — preview on PR, production on merge to main
4. Set health check: the production URL from vercel project settings
```

**中文**：Vercel 的部署策略：PR 上创建 Preview URL，合并到 main 后更新 Production URL。`/setup-deploy` 只需记录生产 URL，部署验证通过轮询完成。

#### Custom/Manual 配置（兜底方案）

**原文**：
```
Use AskUserQuestion to gather the information:
1. How are deploys triggered?
   - A) Automatically on push to main
   - B) Via GitHub Actions workflow
   - C) Via a deploy script or CLI command
   - D) Manually (SSH, dashboard, etc.)
   - E) This project doesn't deploy (library, CLI, tool)
```

**中文**：当所有自动检测都失败时，进入交互式引导流程。四个问题涵盖了所有部署场景：触发方式、生产 URL、健康检查方式、部署前后钩子。

---

## 九、Step 4：配置写入 CLAUDE.md

**原文**：
```markdown
## Deploy Configuration (configured by /setup-deploy)
- Platform: {platform}
- Production URL: {url}
- Deploy workflow: {workflow file or "auto-deploy on push"}
- Deploy status command: {command or "HTTP health check"}
- Merge method: {squash/merge/rebase}
- Project type: {web app / API / CLI / library}
- Post-deploy health check: {health check URL or command}

### Custom deploy hooks
- Pre-merge: {command or "none"}
- Deploy trigger: {command or "automatic on push to main"}
- Deploy status: {command or "poll production URL"}
- Health check: {URL or command}
```

**中文**：配置格式是纯 Markdown，写在 `CLAUDE.md` 的 `## Deploy Configuration` 区块下。

### 配置字段含义解析

| 字段 | 含义 | 示例值 |
|------|------|--------|
| `Platform` | 部署平台 | `fly.io` / `render` / `vercel` |
| `Production URL` | 生产环境 URL | `https://myapp.fly.dev` |
| `Deploy workflow` | 部署触发方式 | `auto-deploy on push` / `.github/workflows/deploy.yml` |
| `Deploy status command` | 检查部署状态的命令 | `fly status --app myapp` |
| `Merge method` | PR 合并方式 | `squash` / `merge` / `rebase` |
| `Project type` | 项目类型 | `web app` / `API` / `CLI` / `library` |
| `Post-deploy health check` | 部署后健康检查 | `https://myapp.fly.dev/health` |

### CLAUDE.md 的角色

```
CLAUDE.md
    │
    ├── ## Deploy Configuration   ← /setup-deploy 写入
    │       ├── Platform: fly.io
    │       ├── Production URL: https://myapp.fly.dev
    │       └── Health check: https://myapp.fly.dev/health
    │
    ├── ## Skill routing          ← Preamble 写入
    │       └── 技能路由规则...
    │
    └── ## Project Notes          ← 用户手写
```

> **设计原理：为什么写入 CLAUDE.md 而非单独的配置文件？**
> 1. **零额外文件**：不创建 `.gstackrc`、`deploy.config.json` 等文件，不污染项目目录
> 2. **可读性**：Markdown 格式，人类可读可编辑
> 3. **版本控制友好**：`CLAUDE.md` 本就应该提交到 git，部署配置一并版本化
> 4. **单一真相源**：所有 gstack 配置集中在一个文件

---

## 十、Step 5：验证配置

**原文**：
```bash
# 验证健康检查 URL
curl -sf "{health-check-url}" -o /dev/null -w "%{http_code}" 2>/dev/null || echo "UNREACHABLE"

# 验证部署状态命令
{deploy-status-command} 2>/dev/null | head -5 || echo "COMMAND_FAILED"
```

**中文**：配置写入后，立即验证：
1. **健康检查 URL**：`curl` 访问，检查 HTTP 状态码
2. **部署状态命令**：实际执行，确认命令可用

重要的是：**即使验证失败，也不阻断流程**。原文明确说明：

```
Report results. If anything failed, note it but don't block — the config is still
useful even if the health check is temporarily unreachable.
```

这是合理的——生产 URL 临时不可达（网络问题、应用重启中）不代表配置错误。配置的正确性比当时的可达性更重要。

---

## 十一、Step 6：最终摘要

**原文**：
```
DEPLOY CONFIGURATION — COMPLETE
════════════════════════════════
Platform:      {platform}
URL:           {url}
Health check:  {health check}
Status cmd:    {status command}
Merge method:  {merge method}

Saved to CLAUDE.md. /land-and-deploy will use these settings automatically.

Next steps:
- Run /land-and-deploy to merge and deploy your current PR
- Edit the "## Deploy Configuration" section in CLAUDE.md to change settings
- Run /setup-deploy again to reconfigure
```

**中文**：清晰的结束摘要，包含：
- 已配置的完整参数表
- 明确告知"配置已保存到 CLAUDE.md"
- 三条 Next Steps 指引用户下一步行动

---

## 十二、重要规则（Important Rules）

**原文**：
```
- Never expose secrets. Don't print full API keys, tokens, or passwords.
- Confirm with the user. Always show the detected config and ask for confirmation before writing.
- CLAUDE.md is the source of truth. All configuration lives there — not in a separate config file.
- Idempotent. Running /setup-deploy multiple times overwrites the previous config cleanly.
```

**中文**：四条核心规则：

| 规则 | 目的 | 实现方式 |
|------|------|---------|
| **不暴露密钥** | 安全性 | `echo $RENDER_API_KEY \| head -c 4`（只显示前4位） |
| **先确认再写入** | 防止误配置 | 展示检测结果后 → AskUserQuestion → 用户确认 → 写入 |
| **CLAUDE.md 是唯一真相源** | 简洁性 | 所有配置集中管理，无散落文件 |
| **幂等性** | 安全性 | 重复运行覆盖旧配置，不叠加不破坏 |

---

## 十三、Completion Status Protocol（完成状态协议）

**原文**：
```
When completing a skill workflow, report status using one of:
- DONE — All steps completed successfully. Evidence provided for each claim.
- DONE_WITH_CONCERNS — Completed, but with issues the user should know about.
- BLOCKED — Cannot proceed. State what is blocking and what was tried.
- NEEDS_CONTEXT — Missing information required to continue.
```

**中文**：每次技能运行结束后，必须报告明确的完成状态：

```
DONE：
  ✓ 平台检测: Fly.io (fly.toml)
  ✓ 生产 URL: https://myapp.fly.dev
  ✓ 健康检查: 200 OK
  ✓ 配置已写入 CLAUDE.md

DONE_WITH_CONCERNS：
  ✓ 配置已写入
  ⚠ 健康检查 URL 当前不可达（临时问题？）
  ⚠ fly CLI 未安装，部署状态命令无法验证

BLOCKED：
  ✗ 无法确定生产 URL
  已尝试: 自动检测（无结果），用户未提供
  建议: 手动设置 Production URL
```

---

## 十四、Operational Self-Improvement（操作自改进）

**原文**：
```
Before completing, reflect on this session:
- Did any commands fail unexpectedly?
- Did you take a wrong approach and have to backtrack?
- Did you discover a project-specific quirk?

If yes, log an operational learning:
gstack-learnings-log '{"skill":"setup-deploy","type":"operational","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":N}'
```

**中文**：每次会话结束前自我反思。如果发现了项目特有的"坑"（比如"这个项目的健康检查路径是 `/api/status` 不是 `/health`"），记录下来，下次自动应用。

这是 gstack 的**跨会话学习机制**：
```
会话 1: 发现 /health 返回 404 → 改用 /api/status → 记录 learning
会话 2: 读取 learning → 直接使用 /api/status → 省去探索
```

---

## 十五、遥测完成记录（Telemetry）

**原文**：
```bash
_TEL_END=$(date +%s)
_TEL_DUR=$(( _TEL_END - _TEL_START ))
rm -f ~/.gstack/analytics/.pending-"$_SESSION_ID" 2>/dev/null || true
~/.claude/skills/gstack/bin/gstack-timeline-log '{"skill":"setup-deploy","event":"completed",...}' 2>/dev/null || true
```

**中文**：技能完成时记录：
- 会话持续时长（`_TEL_END - _TEL_START` 秒）
- 结果（`success` / `error` / `abort`）
- 是否使用了浏览器功能（`USED_BROWSE`）

本地 JSONL 始终记录（即使遥测关闭也记录本地时间线）。远程上报只在 `community` 或 `anonymous` 模式下发生。

---

## 十六、典型使用流程（完整场景示例）

### 场景：新项目首次配置 Fly.io 部署

```
用户: /setup-deploy
    ↓
[Preamble 运行]
    ↓
检查 CLAUDE.md → NO_CONFIG
    ↓
运行平台检测脚本
    → 发现 fly.toml → PLATFORM:fly
    → 提取 app 名: myapp-production
    → 推断 URL: https://myapp-production.fly.dev
    → 检测 fly CLI: /usr/local/bin/fly (已安装)
    → 验证: fly status --app myapp-production → Running
    ↓
AskUserQuestion:
  "检测到 Fly.io 应用 myapp-production。
   生产 URL: https://myapp-production.fly.dev
   是否正确？有些应用使用自定义域名。
   RECOMMENDATION: 选 A（使用推断 URL）
   A) https://myapp-production.fly.dev (推断)
   B) 输入自定义域名
   C) 暂时跳过健康检查"
    ↓
用户选 A
    ↓
写入 CLAUDE.md:
  ## Deploy Configuration (configured by /setup-deploy)
  - Platform: fly.io
  - Production URL: https://myapp-production.fly.dev
  - Deploy status command: fly status --app myapp-production
  - Health check: https://myapp-production.fly.dev/health
    ↓
验证:
  curl https://myapp-production.fly.dev/health → 200
  fly status --app myapp-production → Running
    ↓
输出摘要:
  DEPLOY CONFIGURATION — COMPLETE
  Platform: fly.io
  URL: https://myapp-production.fly.dev
  ...
  STATUS: DONE
```

### 场景：修改现有配置

```
用户: /setup-deploy
    ↓
检查 CLAUDE.md → 发现现有配置
    ↓
展示现有配置
    ↓
AskUserQuestion:
  "已存在部署配置。
   A) 从头重新配置（覆盖）
   B) 修改特定字段
   C) 配置正确，退出"
    ↓
用户选 B（"只改健康检查路径"）
    ↓
AskUserQuestion: "新的健康检查 URL？"
    ↓
Edit CLAUDE.md（只修改该字段）
    ↓
验证新路径
    ↓
STATUS: DONE
```

---

## 十七、技能间协作总结

```
              ┌─────────────────────────────────────────┐
              │           gstack 部署工作流              │
              └─────────────────────────────────────────┘
                                  │
         ┌────────────────────────┼────────────────────────┐
         ▼                        ▼                        ▼
    /office-hours            /setup-deploy            /canary
    （构思阶段）              （配置阶段）              （监控阶段）
    "是否值得做"             "如何部署"               "部署后健康"
         │                        │                        │
         ▼                        ▼                        ▼
      /ship                /land-and-deploy            /benchmark
    （创建 PR）             （合并+部署+验证）          （性能回归检测）
    "发布代码"              "一键上线"                "性能是否退化"
```

`/setup-deploy` 是整个工作流的**基础设施层**：只需运行一次，为所有后续的 `/land-and-deploy` 调用提供配置基础。这是"配置即代码"理念的体现——部署配置本身也应该被版本化和自动化管理。

---

## 十八、关键设计哲学小结

| 设计原则 | 体现方式 |
|----------|----------|
| **一次配置，永久有效** | 写入 CLAUDE.md，后续调用读取而非重新检测 |
| **零打扰检测** | 从文件系统特征文件自动推断平台 |
| **幂等性** | 重复运行覆盖而非叠加，结果可预测 |
| **安全第一** | 不暴露密钥，确认后再写入 |
| **非阻断验证** | 验证失败警告但不阻断，配置仍有价值 |
| **跨会话记忆** | learnings.jsonl 记录项目特有知识 |
| **单一真相源** | CLAUDE.md 是所有部署配置的唯一来源 |
