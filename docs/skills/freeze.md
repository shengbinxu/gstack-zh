# `/freeze` 技能深度注解

> 对应源文件：`freeze/SKILL.md.tmpl`
> 将文件编辑限制在指定目录。

## 核心定位

把 Edit 和 Write 操作锁定到一个目录。目录外的编辑会被**阻止**（不是警告）。

用途：调试时防止"顺手"改了不相关代码，或者想把变更限定在一个模块。

## 实现

```bash
# 状态文件
~/.gstack/freeze-dir.txt
# 内容：/absolute/path/to/allowed/dir/

# hook 脚本检查每次 Edit/Write 的目标路径是否在允许范围内
```

配套技能：`/unfreeze` 清除限制。
