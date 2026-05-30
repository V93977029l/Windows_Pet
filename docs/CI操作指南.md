# CI/CD 操作指南

本文档记录 TransparentPet 项目的 CI/CD 流水线配置、本地测试方法以及日常开发中的测试实践。

---

## 一、CI 流水线概述

### 触发条件

| 事件                          | 说明                              |
| ----------------------------- | --------------------------------- |
| `push` 到 `main` 分支         | 自动触发构建+测试                 |
| `Pull Request` 到 `main` 分支 | 自动触发构建+测试（作为合并门禁） |
| `workflow_dispatch`           | 手动在 GitHub Actions 页面触发    |

### 流水线步骤

```
检出代码（含子模块）
  → 配置 Python + SCons
  → 下载 Godot 4.6.3 引擎
  → 编译 GDExtension 原生扩展
  → 安装 GdUnit4 测试框架
  → 运行单元测试
  → 上传测试报告（HTML/XML）
  → 导出 Windows 构建
  → 上传构建产物
```

### 流水线文件位置

`.github/workflows/ci.yml`

---

## 二、本地运行测试

### 2.1 前提条件

- Godot 引擎已安装（当前项目使用 `4.6.3`）
- 项目根目录为 `f:\VSCode\game\transparent-pet`

### 2.2 通过 Godot 编辑器运行测试

1. 用 Godot 编辑器打开项目
2. 确保 GdUnit4 插件已启用（项目设置 → 插件 → 勾选 gdUnit4）
3. 在文件系统中右键 `tests/` 目录 → 选择 "Run Tests"
4. 在 GdUnit4 面板中查看测试结果

### 2.3 通过命令行运行测试

```powershell
cd f:\VSCode\game\transparent-pet

& "F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" `
  --path "." -s "res://addons/gdUnit4/bin/GdUnitCmdTool.gd" `
  "-a" "res://tests/" "-c" "--ignoreHeadlessMode" "-rd" "test-reports"
```

**参数说明：**

| 参数                   | 说明                                   |
| ---------------------- | -------------------------------------- |
| `--path "."`           | 指定项目路径                           |
| `-s`                   | 运行指定脚本（GdUnit4 CLI 工具）       |
| `-a "res://tests/"`    | 添加测试目录                           |
| `-c`                   | 继续运行所有测试（不因首个失败而停止） |
| `--ignoreHeadlessMode` | **必须** — 允许在非编辑器模式下运行    |
| `-rd "test-reports"`   | 报告输出目录                           |

### 2.4 验证项目能否正常编译

```powershell
# 无窗口模式加载项目（验证无编译错误）
& "F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" `
  --headless --path "transparent-pet" --quit

# 检查单个脚本语法
& "F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" `
  --headless --path "transparent-pet" --check-only -s "res://tests/core/test_event_bus.gd"
```

---

## 三、测试目录结构

```
transparent-pet/tests/
├── core/                          # 核心系统测试
│   ├── test_event_bus.gd          # 事件总线 (8 个测试)
│   └── test_math_utils.gd         # 数学工具 (7 个测试)
└── modules/                       # 功能模块测试
    ├── interaction/
    │   └── test_drag_controller.gd # 拖拽控制器 (7 个测试)
    └── pet/
        └── test_pet_constants.gd   # 宠物常量 (6 个测试)
```

**命名规范：**

- 测试文件命名：`test_<模块名>.gd`
- 测试类名：`class_name Test<ModuleName>`
- 测试方法命名：`test_<功能描述>()`

---

## 四、编写新测试

### 4.1 测试模板

```gdscript
class_name TestMyModule
extends GdUnitTestSuite

var _target


func before_test() -> void:
	_target = MyModule.new()
	add_child(_target)


func after_test() -> void:
	if _target:
		_target.queue_free()


func test_basic_functionality() -> void:
	# Arrange（准备）
	var input := 42

	# Act（执行）
	var result := _target.process(input)

	# Assert（断言）
	assert_int(result).is_equal(84)


func test_edge_case() -> void:
	# 边界条件测试
	assert_bool(_target.is_valid(0)).is_true()
	assert_bool(_target.is_valid(-1)).is_false()
```

### 4.2 常用断言

```gdscript
# 基础类型
assert_int(value).is_equal(expected)
assert_float(value).is_between(0.0, 1.0)
assert_str(text).contains("keyword")
assert_bool(flag).is_true()

# 集合
assert_array(list).contains(expected_item)
assert_that(dict.has("key")).is_true()

# 信号
assert_signal(target.my_signal).is_emitted()
```

### 4.3 注意事项

1. **RefCounted 对象不要调用 `free()`** — `DragController` 等继承 `RefCounted` 的类由引用计数自动管理
2. **闭包陷阱** — GDScript 的 lambda 不会捕获局部变量，需使用 `Dictionary` 或 `Array` 包装
3. **类型匹配** — `assert_float` 只接受 `float`，整型需用 `assert_int`
4. **GdUnit4 扫描** — 测试类需要 `class_name` 声明才能被框架发现

---

## 五、查看测试报告

测试运行后，报告生成在 `test-reports/report_1/` 目录下：

| 文件          | 说明                                |
| ------------- | ----------------------------------- |
| `index.html`  | HTML 格式报告（可在浏览器中打开）   |
| `results.xml` | JUnit XML 格式报告（CI 工具可解析） |

在 CI 中，报告作为 Artifact 上传，可在 GitHub Actions 运行页面下载。

---

## 六、CI 故障排查

### 6.1 Godot 引擎下载失败

检查 GitHub Release 下载 URL 是否可用：

```
https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_win64.exe.zip
```

如果 Godot 版本升级，需同步更新 `.github/workflows/ci.yml` 中的 `GODOT_VERSION` 环境变量。

### 6.2 GDExtension 编译失败

确认 CI 环境满足以下条件：

- Windows runner (`windows-latest`)
- Python 3.11 + SCons 已安装
- `git submodule update --init --recursive` 已执行

本地验证命令：

```powershell
cd f:\VSCode\game\gdextension
python build.py --target=template_debug --platform=windows
```

### 6.3 GdUnit4 测试无法发现

常见原因：

1. 测试文件缺少 `class_name` 声明
2. 脚本有解析错误（先运行 `--check-only` 验证）
3. 使用了不兼容的 GdUnit4 版本（当前项目使用 v6.1.3，对应 Godot 4.6.x）

### 6.4 测试在本地通过但 CI 失败

可能原因：

- CI 使用 headless 模式，部分依赖 UI 的测试无法运行
- 文件路径大小写敏感（Linux CI runner）vs 不敏感（Windows）
- CI 中 GDExtension DLL 未正确编译/部署

---

## 七、快速参考卡片

```powershell
# === Godot 引擎路径（本地） ===
$GODOT = "F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

# === 运行全部测试 ===
cd f:\VSCode\game\transparent-pet
& $GODOT --path "." -s "res://addons/gdUnit4/bin/GdUnitCmdTool.gd" `
  "-a" "res://tests/" "-c" "--ignoreHeadlessMode" "-rd" "test-reports"

# === 运行单个测试套件 ===
& $GODOT --path "." -s "res://addons/gdUnit4/bin/GdUnitCmdTool.gd" `
  "-a" "res://tests/core/test_event_bus.gd" "-c" "--ignoreHeadlessMode"

# === 验证项目编译 ===
& $GODOT --headless --path "." --quit

# === 查看 CI 测试报告 ===
# 浏览器打开: transparent-pet/test-reports/report_1/index.html
```
