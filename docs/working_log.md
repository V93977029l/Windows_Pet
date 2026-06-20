# 开发工作日志 / 已知坑位

> 记录开发中反复出现的问题，供 AI 和开发者跨对话参考。
> 每次踩坑后追加条目，避免重复犯错。

---

## GDScript / Godot 引擎

### class_name 必须在 extends 之前

- **症状：** Godot 4.x 报解析错误
- **正确：** `class_name MyClass` → `extends Node`
- **错误：** `extends Node` → `class_name MyClass`

### 删除 .godot 目录后项目无法编译

- **症状：** UID 解析失败、GdUnit4 类找不到
- **原因：** `.godot` 是 Godot 的导入缓存，删除后需用编辑器重新打开项目导入
- **教训：** 不要随便删 `.godot/`，除非明确需要通过编辑器重建

### 复制场景文件导致 UID 冲突

- **症状：** `class_name` 重复声明、场景加载报错
- **原因：** 复制 `.tscn` 时 UID 不变，Godot 认为是同一资源
- **解决：** 移动文件用 Godot 编辑器操作，或手动修改 UID

### GDScript 变量名遮蔽基类属性

- **症状：** `var scale: float` 在 extends Node2D 的类中与 `Node2D.scale` 冲突
- **解决：** 重命名变量（如 `var new_scale: float`）

---

## CI / GitHub Actions

### `${{ env.APPDATA }}` 在 actions/cache 中无效

- **症状：** 导出模板缓存路径错误，Godot 找不到模板
- **原因：** GitHub Actions 表达式中 `env.APPDATA` 取的是 workflow `env:` 块中定义的变量，不是 Windows 系统环境变量
- **解决：** 先在 PowerShell 步骤中 `echo "VAR=$env:APPDATA\path" >> $env:GITHUB_ENV`，再在 cache 步骤用 `${{ env.VAR }}`

### PowerShell 不支持 `&&` 连接命令

- **正确：** 用 `;` 分隔（`cmd1; cmd2`）
- **备选：** 分两个 RunCommand 调用

### pre-commit mixed-line-ending 失败

- **症状：** CRLF/LF 不一致被 pre-commit hook 修复，但仍需 `git add` 重新暂存后再次 commit
