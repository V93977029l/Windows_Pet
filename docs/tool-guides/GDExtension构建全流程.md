# GDExtension 构建全流程

本文档详细介绍了本项目中 GDExtension 的构建全流程，包括目录结构、编译指令和具体步骤。

## 一、目录结构

### 1. 核心目录

| 目录路径                                   | 说明                             | 重要性 |
| ------------------------------------------ | -------------------------------- | ------ |
| `gdextension/`                             | GDExtension 相关代码的根目录     | 核心   |
| `external/godot-cpp/`                      | Godot C++ 绑定库 (Git Submodule) | 核心   |
| `gdextension/mouse_passthrough_extension/` | 鼠标穿透插件的实现               | 核心   |
| `gdextension/system_tray_extension/`       | 系统托盘插件的实现               | 核心   |
| `gdextension/liquid_glass_extension/`      | 液态玻璃特效插件的实现           | 核心   |
| `transparent-pet/addons/`                  | Godot 项目中的插件目录           | 核心   |

### 2. 重要文件

| 文件路径                   | 说明                 | 重要性 |
| -------------------------- | -------------------- | ------ |
| `.gitmodules`              | Git Submodule 配置   | 核心   |
| `gdextension/build.py`     | 一键构建和部署脚本   | 重要   |
| `gdextension/*/SConstruct` | 各插件的构建配置文件 | 核心   |

## 二、构建环境准备

### 1. 依赖项

- **Python 3.7+**：用于运行 SCons 构建系统
- **SCons**：Godot 官方推荐的构建工具
- **Visual Studio 2022+**：Windows 平台的 C++ 编译器（推荐）
- **Godot 4.3+**：用于测试和运行插件
- **Git & Git LFS**：版本控制和大文件管理

### 2. 安装步骤

1. **安装 Python**：从 [Python 官网](https://www.python.org/) 下载并安装 Python 3.7+
2. **安装 SCons**：
   ```bash
   pip install scons
   ```
3. **安装 Visual Studio**：安装 Visual Studio 2022 或更高版本，并安装「使用 C++ 的桌面开发」工作负载
4. **初始化 Git LFS**（首次仅需一次）：
   ```bash
   git lfs install
   ```

### 3. 首次克隆项目

```bash
# 克隆项目并初始化子模块
git clone --recurse-submodules 你的仓库地址
cd game
```

如果已经克隆了项目但没有初始化子模块：

```bash
git submodule init
git submodule update
```

## 三、构建步骤

### 1. 一键构建（推荐）

本项目提供了 `gdextension/build.py` 一键构建脚本，是最简单的方式：

```bash
# 进入 gdextension 目录
cd gdextension

# 运行一键构建脚本
python build.py
```

这个脚本会自动：

1. 验证 godot-cpp 完整性
2. 编译 godot-cpp（如果需要）
3. 编译所有 GDExtension 插件
4. 自动部署 DLL 文件到 `transparent-pet/addons/`

### 2. 单独构建各插件

如果需要单独构建某个插件：

#### 构建鼠标穿透插件

```bash
cd gdextension/mouse_passthrough_extension
scons
```

#### 构建系统托盘插件

```bash
cd gdextension/system_tray_extension
scons
```

#### 构建液态玻璃插件

```bash
cd gdextension/liquid_glass_extension
scons
```

### 3. 手动构建 godot-cpp（通常不需要）

godot-cpp 作为 Git Submodule 管理，通常不需要手动构建。如果确实需要：

```bash
# 进入 godot-cpp 目录
cd external/godot-cpp

# Windows Debug 模式（关闭 LTO 加速开发）
scons platform=windows target=debug -j12 lto=no

# Windows Release 模式
scons platform=windows target=release -j12 lto=full
```

## 四、编译加速体系

本项目配置了 Windows 专属的编译加速体系，主要特性：

### 核心特性

1. **Git Submodule 管理**：godot-cpp 和外部参考作为子模块统一管理
2. **SCons 默认配置固化**：Windows 默认平台、Debug 默认关闭 LTO
3. **多插件并行构建**：`build.py` 支持同时构建多个插件
4. **自动部署**：构建后自动部署到正确的插件目录

## 五、构建配置说明

### 1. GDExtension 配置文件

每个插件都有自己的 `.gdextension` 配置文件，示例：

```ini
[configuration]
entry_symbol = "mouse_passthrough_library_init"
compatibility_minimum = "4.3"

[libraries]
windows.x86_64 = "res://addons/mouse_passthrough/bin/libmouse_passthrough.windows.template_debug.x86_64.dll"
windows.template_debug.x86_64 = "res://addons/mouse_passthrough/bin/libmouse_passthrough.windows.template_debug.x86_64.dll"
windows.template_release.x86_64 = "res://addons/mouse_passthrough/bin/libmouse_passthrough.windows.template_release.x86_64.dll"
```

## 六、常见问题及解决方案

### 1. 构建失败：找不到编译器

**原因**：Visual Studio 未正确安装或未添加到环境变量

**解决方案**：

- 重新安装 Visual Studio 2022+
- 确保安装了「使用 C++ 的桌面开发」工作负载
- 重启终端或电脑使环境变量生效

### 2. 构建失败：找不到 godot-cpp 头文件

**原因**：godot-cpp 子模块未正确初始化

**解决方案**：

- 确保已运行 `git submodule init && git submodule update`
- 检查 `external/godot-cpp/` 目录是否有文件

### 3. 插件加载失败：找不到 DLL 文件

**原因**：DLL 文件未正确复制到 Godot 项目目录

**解决方案**：

- 运行 `gdextension/build.py` 脚本进行自动部署
- 或手动复制到 `transparent-pet/addons/*/bin/` 目录

## 七、构建命令速查表

| 命令                                                | 说明                   | 适用场景   |
| --------------------------------------------------- | ---------------------- | ---------- |
| `cd gdextension; python build.py`                   | 一键构建和部署所有插件 | 日常开发   |
| `cd gdextension/mouse_passthrough_extension; scons` | 构建鼠标穿透插件       | 单独开发   |
| `cd gdextension/system_tray_extension; scons`       | 构建系统托盘插件       | 单独开发   |
| `cd gdextension/liquid_glass_extension; scons`      | 构建液态玻璃插件       | 单独开发   |
| `scons -c`                                          | 清理构建产物           | 重新构建时 |
| `git submodule update --remote`                     | 更新子模块到最新版本   | 升级依赖   |

## 八、总结

GDExtension 是 Godot 4 引入的一种扩展机制，允许使用 C++ 编写高性能的插件。本项目包含三个 GDExtension 插件：鼠标穿透、系统托盘和液态玻璃特效。

推荐使用 `gdextension/build.py` 一键构建脚本，简单高效！

---

**注意**：本文档适用于本项目的特定结构，其他项目可能需要根据实际情况进行调整。
