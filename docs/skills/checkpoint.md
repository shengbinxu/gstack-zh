# `/checkpoint` 技能深度注解

> 对应源文件：[`checkpoint/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/checkpoint/SKILL.md.tmpl)
> 保存/恢复工作状态——AI 会话的"存档点"。

---

## 这个技能是什么？

**人设**："保持细致会话笔记的 Staff 工程师"。

**HARD GATE**：不写代码，只捕获和恢复上下文。

**触发时机**：要切换上下文、长休息、跨分支工作。

---

## 三个命令

```
/checkpoint           保存当前状态（= /checkpoint save）
/checkpoint save      同上
/checkpoint resume    恢复最近的 checkpoint
/checkpoint list      列出所有 checkpoint
```

---

## Save 流程

```
/checkpoint save [title]
     │
     ▼
┌─────────────────────────────────┐
│ 收集状态：                       │
│ ├─ git branch + status + log   │
│ ├─ 未提交的变更 diff            │
│ ├─ 当前会话中做了哪些决策       │
│ ├─ 剩余工作（还有什么没做）     │
│ └─ 相关的 TODOS.md 项          │
├─────────────────────────────────┤
│ 写入：                           │
│ ~/.gstack/projects/<slug>/      │
│   checkpoint-<branch>-<time>.md │
└─────────────────────────────────┘
```

## Resume 流程

```
/checkpoint resume
     │
     ▼
┌─────────────────────────────────┐
│ 1. 找到最近的 checkpoint 文件   │
│ 2. 读取内容                     │
│ 3. 检查 git 状态是否匹配       │
│ 4. 输出完整上下文               │
│    "你在做 X，已经完成 Y，      │
│     还剩 Z，上次在分支 B 上"    │
└─────────────────────────────────┘
```

---

## 关键设计决策

| 决策 | 原因 |
|------|------|
| HARD GATE 不写代码 | 纯上下文操作，防止副作用 |
| 包含决策记录 | 不只是 git 状态，还有"为什么这样做" |
| 跨分支 | Conductor 工作区切换时保持上下文 |
| 持久化到 ~/.gstack/ | 跨会话存活 |
