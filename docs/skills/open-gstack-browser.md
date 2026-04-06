# `/open-gstack-browser` 技能深度注解

> 对应源文件：[`open-gstack-browser/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/open-gstack-browser/SKILL.md.tmpl)
> 可见 AI 浏览器——实时观看 AI 操作。

---

## 这个技能是什么？

启动有界面的 Chromium（headed 模式），内置 gstack sidebar 扩展。

**vs /browse**：/browse 是无头的（看不到），这个有窗口——用户可以实时看到 AI 在干什么。

---

## 特性

- **Anti-bot stealth**：伪造 navigator.plugins、清理 CDP 痕迹、自定义 UA
- **视觉指示器**：页面顶部琥珀色渐变条，提醒这是 AI 控制的浏览器
- **Sidebar 扩展**：实时 activity feed + chat 界面
- **macOS 品牌化**：替换 Dock 图标 + Info.plist
- **持久 profile**：`~/.gstack/chromium-profile`（保留 cookie/历史/扩展）

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| Headed 模式 | 用户需要看到 AI 在做什么 |
| Anti-bot | 避免被网站检测为自动化 |
| 持久 profile | 登录状态跨会话保持 |
| 视觉指示器 | 安全提醒——这是 AI 控制的 |
