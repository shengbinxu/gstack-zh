# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目性质

这是一个**纯文档仓库**，无代码、无构建步骤、无测试命令。内容是对 [garrytan/gstack](https://github.com/garrytan/gstack) 的中文深度注解学习指南。

## 文档结构

```
docs/
  skills/          # 38 个技能的逐段中英对照注解（每文件对应一个 /skill 命令）
  architecture.md  # 无头浏览器守护进程、Bun 选型、整体架构
  how-skills-work.md   # 技能模板系统解析（.tmpl → SKILL.md 管线、9个模板变量）
  browse-daemon.md     # Browse 守护进程源码解读
  design-binary.md     # Design 二进制源码解读
  template-pipeline.md # 模板编译管线详解
SYNC.md          # 当前对齐的上游版本号、日期、upstream commit SHA
```

## 注解文件格式规范

每个 `docs/skills/*.md` 的结构：
1. 保留英文原文（用 `> **原文**:` 块引用）
2. 中文翻译对照
3. 设计原理解读（"为什么这样设计"，不只是"这里写了什么"）

**不要**：
- 修改任何英文原文（原文仅做引用，不可改动）
- 只做翻译，不做设计解读
- 写摘要代替逐段注解

## 版本同步流程

### SYNC.md 格式
```
gstack-version: v0.16.4.0
synced-at: 2026-04-14
upstream-sha: 7e96fe299b085010fb2e34d9c4fbfc7e44b617e1
```

`upstream-sha` 是本次同步时上游 `garrytan/gstack` 的 HEAD commit SHA，是 diff 基准点。

### 同步一个新版本的步骤
1. GitHub Actions（每日 UTC 08:00）自动检测：对比 `SYNC.md` 中 `upstream-sha` 与上游当前 HEAD，有新 commit 则开 Issue，列出变更文件和 commit 列表
2. 人工处理：查看 Issue → 更新对应 `docs/skills/*.md` 注解 → 更新 `SYNC.md`（三个字段都要更新）→ commit → 打 tag → 关闭 Issue

### 获取上游变更
```bash
# 查看自上次同步以来的变更文件
gh api "repos/garrytan/gstack/compare/<last-sha>...<new-sha>" --jq '[.files[] | .filename] | join("\n")'

# 获取某文件的 diff
gh api "repos/garrytan/gstack/compare/<last-sha>...<new-sha>" --jq '.files[] | select(.filename == "review/SKILL.md") | .patch'

# 查看某文件的当前内容
gh api "repos/garrytan/gstack/contents/review/SKILL.md" --jq '.content' | base64 -d
```

## Commit 规范

- `sync: update annotations to gstack vX.Y.Z` — 版本同步
- `docs: <内容描述>` — 文档改进
- `fix: <问题描述>` — 修复错误

每个 commit 附加：`Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`

打 tag（不 push，等人工确认）：
```bash
git tag -a vX.Y.Z -m "Sync with gstack vX.Y.Z"
git push origin vX.Y.Z
```
