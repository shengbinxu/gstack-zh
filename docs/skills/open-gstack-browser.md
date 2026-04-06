# `/open-gstack-browser` 技能深度注解

> 对应源文件：[`open-gstack-browser/SKILL.md.tmpl`](https://github.com/garrytan/gstack/blob/main/open-gstack-browser/SKILL.md.tmpl)
> 启动 GStack Browser：可见的 AI 控制 Chromium。

## 核心定位

启动可见的（非无头）Chromium 窗口，内置 sidebar 扩展和反检测。你可以实时看到 AI 的每一个操作。

## 与普通 browse 的区别

| | 普通 browse | GStack Browser |
|-|------------|----------------|
| 可见性 | 无头（不可见） | 可见窗口 |
| Sidebar | 无 | 内置 activity feed + chat |
| 反检测 | 基础 | 完整反机器人检测 |
| 用途 | 自动化测试 | 演示、实时观看、手动+AI混合操作 |

## Pre-flight 清理

启动前自动清理：杀旧服务器、删 Chromium profile 锁文件（崩溃后可能残留）。
