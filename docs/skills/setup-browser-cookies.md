# `/setup-browser-cookies` 技能深度注解

> 对应源文件：`setup-browser-cookies/SKILL.md.tmpl`
> 从真实浏览器导入 Cookie 到无头浏览器会话。

## 核心定位

QA 测试需要认证的页面时，从你的 Chromium 浏览器解密并导入 cookie。打开交互式选择器 UI，让你选择哪些域名的 cookie 要导入。

## CDP 模式检测

如果 browse 已经连接到你的真实浏览器（CDP 模式），直接告诉用户"不需要导入"。真实浏览器的 cookie 已经可用。

## 流程

1. 找到 browse 二进制
2. 运行 `cookie-import-browser`
3. 自动检测已安装的 Chromium 浏览器
4. 打开交互式选择器
5. 解密并加载 cookie 到 Playwright 会话
