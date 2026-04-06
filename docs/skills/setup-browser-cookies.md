# `/setup-browser-cookies` 技能深度注解

> 对应源文件：[`setup-browser-cookies/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/setup-browser-cookies/SKILL.md.tmpl)
> 从真实浏览器导入 Cookie 到无头会话。

---

## 这个技能是什么？

**触发时机**：QA 测试需要登录的页面前。

**核心流程**：
1. 检测用户安装了哪些浏览器（Chrome/Safari/Firefox）
2. 打开交互式 cookie picker UI
3. 用户选择要导入的域名
4. 导入 cookie 到 browse 守护进程

**解决的问题**：无头浏览器没有用户的登录状态。
这个技能从真实浏览器提取 cookie，让无头浏览器可以访问需要登录的页面。

---

## 总结

| 设计决策 | 原因 |
|---------|------|
| 交互式选择器 | 用户控制导入哪些 cookie |
| 支持多浏览器 | Chrome/Safari/Firefox |
| 安全：用户选择域名 | 不会导入所有 cookie |
