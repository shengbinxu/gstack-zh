# `/cso` 技能深度注解

> 对应源文件：[`cso/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/cso/SKILL.md.tmpl)（636 行）
> gstack 最长的技能之一——首席安全官审计。

---

## 这个技能是什么？

`/cso` 把 Claude 变成一个"经历过真实安全事件的 CSO"。

**触发时机**：安全审计、威胁建模、上线前检查。

**它做什么**：
- 15 个审计阶段（Phase 0-14），从基础设施到应用层
- 两种模式：daily（8/10 置信度，零噪声）和 comprehensive（2/10）
- 独立子 Agent 验证每个发现
- 22 条硬排除规则 + 15 条先例，严控误报
- 趋势追踪（vs 上次审计）

**不做什么**：不改代码，只出报告。

---

## 核心审计流程

```
/cso [flags]
     │
     ▼
┌───────────────────────────────────┐
│ P0: Architecture Mental Model     │
│    技术栈/框架检测 + 信任边界     │
├───────────────────────────────────┤
│ P1: Attack Surface Census         │
│    代码面 + 基础设施面            │
├───────────────────────────────────┤
│ P2: Secrets Archaeology           │
│    git history/env/CI 密钥泄露    │
├───────────────────────────────────┤
│ P3: Dependency Supply Chain       │
│    CVE + install script + lockfile│
├───────────────────────────────────┤
│ P4: CI/CD Pipeline Security       │
│    unpinned actions/injection     │
├───────────────────────────────────┤
│ P5: Infrastructure Shadow         │
│    Docker/IaC/prod credentials    │
├───────────────────────────────────┤
│ P6: Webhook & Integration         │
│    无签名验证/TLS disabled        │
├───────────────────────────────────┤
│ P7: LLM & AI Security            │
│    prompt injection/cost attack   │
├───────────────────────────────────┤
│ P8: Skill Supply Chain            │
│    恶意 Claude Code skill 扫描   │
├───────────────────────────────────┤
│ P9: OWASP Top 10                  │
│    A01-A10 逐项                   │
├───────────────────────────────────┤
│ P10: STRIDE Threat Model          │
│    S/T/R/I/D/E per component     │
├───────────────────────────────────┤
│ P11: Data Classification          │
│    RESTRICTED/CONFIDENTIAL/...    │
├───────────────────────────────────┤
│ P12: FP Filter + Verification     │
│    22 条排除 + 独立 Agent 验证   │
├───────────────────────────────────┤
│ P13: Report + Remediation         │
│    每个发现附攻击场景 + Top 5 修复│
├───────────────────────────────────┤
│ P14: Save to .gstack/             │
└───────────────────────────────────┘
```

---

## 关键设计决策

### 基础设施优先

```
The real attack surface isn't your code — it's your dependencies.
```

Phase 2-6 在 Phase 9（OWASP）之前。真实安全事件大多来自泄露密钥、unpinned CI actions、被遗忘的 staging——不是 SQL 注入。

### 8/10 置信度门槛

```
Daily mode: Below 8 = do not report. Period.
```

安全报告的杀手是噪声。3 个真实发现 > 3 个真实 + 12 个理论风险。用户停止阅读噪声报告后，真正漏洞被埋没。

### 22 条硬排除规则

从真实误报经验提炼。注意关键例外：
- DoS 排除**不适用于** LLM 成本放大（财务风险）
- CI/CD 排除**不适用于** Phase 4 的 pipeline 发现
- Markdown 排除**不适用于** SKILL.md（可执行 prompt）

### 独立子 Agent 验证

主审计可能有锚定效应。子 Agent 只看文件+位置，独立评判。模拟安全团队的"四眼原则"。

### LLM Security（Phase 7）

其他安全工具几乎不覆盖的新攻击类别：
- 用户输入进 system prompt？
- LLM 输出渲染 HTML？
- tool calling 无验证？
- 无限 LLM 调用（成本攻击）？

### Skill Supply Chain（Phase 8）

基于 Snyk ToxicSkills 研究：36% 的 published skills 有安全缺陷，13.4% 恶意。

### 参数化审计

```
/cso                  全量 daily
/cso --comprehensive  月度深度（2/10 门槛）
/cso --infra         只审基础设施
/cso --code          只审代码
/cso --skills        只审 skill 供应链
/cso --diff          只审当前分支（可组合）
/cso --owasp         OWASP Top 10
/cso --scope auth    聚焦特定领域
```

作用域 flag 互斥，`--diff` 可组合。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 基础设施优先 | 真实攻击面在依赖和配置 |
| 8/10 置信度 | 零噪声 > 零遗漏 |
| 22 条硬排除 | 真实误报经验 |
| 独立 Agent 验证 | 消除锚定效应 |
| LLM Security | 新攻击面 |
| Skill Supply Chain | 13.4% 恶意 skill |
| 趋势追踪 | 安全态势可见 |
| 只读 | CSO 不改代码 |
