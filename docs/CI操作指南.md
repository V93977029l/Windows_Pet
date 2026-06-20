# CI/CD 操作指南

本文档记录 TransparentPet 项目的 CI/CD 流水线配置、本地测试方法以及日常开发中的测试实践。

---

## 一、CI 流水线概述

### 触发条件

| 事件                          | 说明                                                  |
| ----------------------------- | ----------------------------------------------------- |
| `push` 到 `main` 分支         | 自动触发：测试 + 代码扫描 + 构建导出 + GitHub Release |
| `push` 到 `dev/*` 分支        | 自动触发：测试 + 代码扫描（**不构建导出**）           |
| `Pull Request` 到 `main` 分支 | 自动触发：测试 + 代码扫描（作为合并门禁）             |
| `workflow_dispatch` 手动触发  | 可选择是否运行构建导出                                |

### 两个 Job 结构

```
┌──────────────────────────────────────────────────────────┐
│  Job 1: test（**所有事件触发）                            │
│  ┌─ 安装 Godot 4.6.3                                    │
│  ├─ 安装 GdUnit4 测试框架                             │
│  ├─ GDScript 代码扫描（语法检查、调试残留、过长行）          │
│  └─ 运行单元测试 → 生成测试报告 → Codecov 覆盖率         │
└──────────────────────────────────────────────────────────┘
                             ↓ 通过才运行
┌──────────────────────────────────────────────────────────┐
│  Job 2: build-export（**仅 main push 或手动勾选）        │
│  ┌─ 安装 Godot 4.6.3                                    │
│  ├─ 安装 Godot 导出模板                                    │
│  ├─ 验证 GDExtension DLL 已编译产物                    │
│  ├─ Godot 导出 Windows .exe                        │
│  └─ 上传构建产物 → GitHub Release（仅 main）                 │
└──────────────────────────────────────────────────────────┘
```

> **重要设计原则**：`build-export` 用 `needs: test` 依赖 `test` job — 测试失败就不会构建导出，确保 main 分支的 Release 产物永远是通过了测试的。

### 流水线文件

`.github/workflows/ci.yml`

---

## 二、本地运行测试与代码扫描

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

### 2.4 本地代码扫描

项目在 `transparent-pet/tools/code_scanner.gd` 内置了 GDScript 代码扫描器，CI 中会自动运行。检查内容包括：

- 语法完整性
- 调试残留的 `print()` 调用
- 无说明文字的 TODO/FIXME
- 超长行（超过 160 字符）

本地运行方式：

```powershell
cd f:\VSCode\game

& "F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" `
  --headless --path "transparent-pet" -s "res://tools/code_scanner.gd"
```

退出码：`0` = 无问题，`非 0` = 有问题需修复

### 2.5 验证项目能否正常编译

```powershell
# 无窗口模式加载项目（验证无编译错误）
& "F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" `
  --headless --path "transparent-pet" --quit

# 检查单个脚本语法
& "F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" `
  --headless --path "transparent-pet" --check-only -s "res://tests/core/test_event_bus.gd"
```

---

## 三、手动构建导出（workflow_dispatch）

`dev/*` 分支 push 时**不会自动构建导出**，只跑测试。如需要在 dev 分支生成 .exe 测试，可手动触发。

**操作步骤：**

1. 打开 Actions 页面：https://github.com/V93977029l/Windows_Pet/actions
2. 选择 "Godot CI - Build & Test" 工作流
3. 点击 "Run workflow" 按钮（页面右侧）
4. 在下拉框中选择分支（如 `dev/fan`）
5. **`build_export` 输入框填 `true`**（默认 `false` 表示只跑测试不构建）
6. 点击绿色 "Run workflow" 按钮开始
7. 等待约 3-5 分钟，完成后在运行详情页下载 artifact

**`build_export` 参数说明：**

| 值              | 行为                                                                |
| --------------- | ------------------------------------------------------------------- |
| `false`（默认） | 只跑 `test` job（代码扫描 + 单元测试），约 1-2 分钟                 |
| `true`          | 测试通过后额外跑 `build-export` job，生成 Windows .exe，约 3-5 分钟 |

**什么时候需要手动构建？**

- 在 dev 分支做了功能改动，想生成一个可执行文件自己测试
- PR 审查者想实际运行一下改动后的版本
- main 分支构建失败需在其他分支复现问题

---

## 四、测试目录结构

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

## 五、编写新测试

### 5.1 测试模板

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

### 5.2 常用断言

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

### 5.3 注意事项

1. **RefCounted 对象不要调用 `free()`** — `DragController` 等继承 `RefCounted` 的类由引用计数自动管理
2. **闭包陷阱** — GDScript 的 lambda 不会捕获局部变量，需使用 `Dictionary` 或 `Array` 包装
3. **类型匹配** — `assert_float` 只接受 `float`，整型需用 `assert_int`
4. **GdUnit4 扫描** — 测试类需要 `class_name` 声明才能被框架发现

---

## 六、查看测试报告

测试运行后，报告生成在 `test-reports/report_1/` 目录下：

| 文件          | 说明                                |
| ------------- | ----------------------------------- |
| `index.html`  | HTML 格式报告（可在浏览器中打开）   |
| `results.xml` | JUnit XML 格式报告（CI 工具可解析） |

在 CI 中，报告作为 Artifact 上传，可在 GitHub Actions 运行页面下载。

---

## 七、CI 故障排查

### 7.1 Godot 引擎下载失败

检查 GitHub Release 下载 URL 是否可用：

```
https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_win64.exe.zip
```

如果 Godot 版本升级，需同步更新 `.github/workflows/ci.yml` 中的 `GODOT_VERSION` 环境变量。

### 7.2 GDExtension 编译（当前不跑）

**当前项目策略：** GDExtension DLL 已预编译并直接提交到仓库，CI 不再执行 SCons 编译步骤。CI 中 `build-export` job 只做一次 DLL 存在性校验。

如果你修改了 gdextension 源代码，需要在本地重新编译后提交新的 DLL：

```powershell
cd f:\VSCode\game\gdextension
python build.py --target=template_release --platform=windows
```

编译完成后，将生成的 `.dll` 文件（位于 `transparent-pet/bin/` 下）提交到 git。

### 7.3 GdUnit4 测试无法发现

常见原因：

1. 测试文件缺少 `class_name` 声明
2. 脚本有解析错误（先跑代码扫描验证）
3. 使用了不兼容的 GdUnit4 版本（当前项目使用 v6.1.3，对应 Godot 4.6.x）

### 7.4 测试在本地通过但 CI 失败

可能原因：

- CI 使用 headless 模式，依赖 UI 的测试无法运行
- CI runner 环境差异（Windows 上已在 windows-latest 跑）
- 测试报告路径或缓存配置问题

### 7.5 GitHub Action 版本号错误（高频踩坑）

**症状**：CI 一启动就报 `Unable to resolve action xxx@vN, unable to find version vN`

**根本原因**：action 用了不存在的版本号。必须使用 action 官方发布中的实际 tag。

**当前项目使用的正确版本号（Node 24 原生支持）：**

| Action                        | 正确版本 | 说明         |
| ----------------------------- | -------- | ------------ |
| `actions/checkout`            | `@v6`    | Node 24 原生 |
| `actions/cache`               | `@v5`    | Node 24 原生 |
| `actions/upload-artifact`     | `@v6`    | Node 24 原生 |
| `actions/setup-python`        | `@v6`    | Node 24 原生 |
| `softprops/action-gh-release` | `@v3`    | Node 24 原生 |
| `codecov/codecov-action`      | `@v5`    | 第三方       |

### 7.6 代码扫描失败

代码扫描器 `code_scanner.gd` 在 CI 中失败时，查看 "GDScript Code Scan" 步骤的输出。常见原因：

- **遗留的 `print()`**：调试代码忘记删除，提交到了仓库 → 删除或改成 `print_debug()`（生产环境不输出）
- **TODO 没有说明文字**：写了 `# TODO` 但没有内容 → 补充说明如 `# TODO: 实现宠物移动动画`
- **语法错误**：某个 .gd 文件无法被 Godot 解析 → 在 Godot 编辑器中打开该文件查看报错

---

## 八、快速参考卡片

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
