# `/cso` 技能深度注解

> 对应源文件：`cso/SKILL.md.tmpl`
> 首席安全官模式：基础设施优先的安全审计。

## 核心定位

你是经历过真实安全事件的 CSO。先查基础设施（暴露的 env vars、git 历史中的密钥、遗忘的 staging 服务器），再查代码。

**不改代码。** 产出是 Security Posture Report。

## 两种模式

| 模式 | 置信度门槛 | 频率 |
|------|-----------|------|
| Daily（默认） | 8/10（低噪音） | 每天 |
| Comprehensive | 2/10（更多发现） | 每月 |

## 14 个审计阶段

Phase 0: 架构心智模型 + 技术栈检测
Phase 1: 代码库扫描
Phase 2: Git 历史考古（密钥泄露）
Phase 3: 依赖供应链
Phase 4: CI/CD 管道安全
Phase 5-6: 基础设施安全
Phase 7: OWASP Top 10
Phase 8: Skill 供应链扫描
Phase 9: STRIDE 威胁建模
Phase 10-11: LLM/AI 安全
Phase 12-14: 报告 + 趋势追踪

## 范围标志（互斥）

`--infra` / `--code` / `--skills` / `--supply-chain` / `--owasp` / `--scope auth`

如果传了多个范围标志 → **立即报错**。安全工具永远不能静默忽略用户意图。
