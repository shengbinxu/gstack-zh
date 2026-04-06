# `/browse` 技能深度注解

> 对应源文件：[`browse/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/browse/SKILL.md.tmpl)
> 快速无头浏览器，QA 测试和 dogfooding 的基础工具。

## 核心定位

持久化无头 Chromium。首次调用自动启动（~3s），之后每次命令 ~100ms。Cookie、标签页、登录状态跨命令保持。

## 核心 QA 模式

```bash
# 1. 验证页面加载
$B goto https://yourapp.com
$B text                    # 内容？
$B console                 # JS 错误？
$B network                 # 失败请求？

# 2. 测试用户流程
$B snapshot -i             # 看所有交互元素
$B fill @e3 "user@test.com"
$B click @e5               # 提交
$B snapshot -D             # diff：提交后什么变了？

# 3. 断言元素状态
$B is visible ".modal"
$B is enabled "#submit-btn"
$B is checked "#agree-checkbox"
```

## 设计特点

- **snapshot -D（diff）**：行动前后自动对比，精确显示什么变了
- **snapshot -i（interactive）**：标记所有可交互元素（@e1, @e2...）
- **snapshot -C（clickable）**：找到非 ARIA 的可点击元素（cursor:pointer, onclick）
- **状态持久化**：cookies 和登录跨命令保留
