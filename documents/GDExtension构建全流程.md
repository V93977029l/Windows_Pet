# GDExtension 构建全流程

本文档详细介绍了本项目中 GDExtension 的构建全流程，包括目录结构、编译指令和具体步骤。

## 一、目录结构

### 1. 核心目录

| 目录路径                                        | 说明                   | 重要性 |
| ------------------------------------------- | -------------------- | --- |
| `gdextension/`                              | GDExtension 相关代码的根目录 | 核心  |
| `gdextension/godot-cpp/`                    | Godot C++ 绑定库 (Git Submodule) | 核心  |
| `gdextension/mouse_passthrough_extension/`  | 鼠标穿透插件的实现            | 核心  |
| `transparent-pet/addons/mouse_passthrough/` | Godot 项目中的插件目录       | 核心  |
| `.ccache/` | CCache 缓存目录（Git LFS 托管） | 重要  |

### 2. 重要文件

| 文件路径                                                                    | 说明               | 重要性 |
| ----------------------------------------------------------------------- | ---------------- | --- |
| `.gitmodules` | Git Submodule 配置 | 核心  |
| `.gitattributes` | Git LFS 配置 | 重要  |
| `gdextension/mouse_passthrough_extension/SConstruct`                    | 插件的构建配置文件        | 核心  |
| `gdextension/build.py` | 一键构建和部署脚本 | 重要  |
| `gdextension/mouse_passthrough_extension/src/mouse_passthrough.cpp`     | 鼠标穿透功能的实现        | 核心  |
| `gdextension/mouse_passthrough_extension/src/mouse_passthrough.h`       | 鼠标穿透类的头文件        | 核心  |
| `gdextension/mouse_passthrough_extension/src/register_types.cpp`        | 插件的注册文件          | 核心  |
| `gdextension/mouse_passthrough_extension/mouse_passthrough.gdextension` | GDExtension 配置文件 | 核心  |
| `transparent-pet/addons/mouse_passthrough/mouse_passthrough.gd`         | 插件的 GDScript 包装  | 核心  |

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
5. **安装 CCache（可选但推荐）**：用于加速重复编译
   - 使用 Chocolatey：`choco install ccache`
   - 或从 [CCache 官网](https://ccache.dev/) 下载安装

### 3. 首次克隆项目

```bash
# 克隆项目并初始化子模块
git clone --recurse-submodules 你的仓库地址
cd game

# 拉取 Git LFS 大文件
git lfs pull
```

如果已经克隆了项目但没有初始化子模块：
```bash
git submodule init
git submodule update
git lfs pull
```

## 三、构建步骤

### 1. 构建 godot-cpp（通常不需要，已预编译）

godot-cpp 预编译库已通过 Git LFS 托管，通常不需要重新构建。如果确实需要重新构建：

```bash
# 进入 godot-cpp 目录
cd gdextension/godot-cpp

# Windows Debug 模式（关闭 LTO 加速开发）
scons platform=windows target=debug -j12 lto=no

# Windows Release 模式
scons platform=windows target=release -j12 lto=full
```

### 2. 构建鼠标穿透插件

```bash
# 进入鼠标穿透插件目录
cd gdextension/mouse_passthrough_extension

# 构建插件（默认 Windows Debug 模式，自动关闭 LTO）
scons

# 或者手动指定参数
scons platform=windows target=debug -j12 lto=no
```

### 3. 部署插件到 Godot 项目

推荐使用一键构建和部署脚本：

```bash
# 进入 gdextension 目录
cd gdextension

# 运行一键构建脚本
python build.py
```

或者手动部署：

```bash
# 复制 DLL 文件到 Godot 项目
copy bin\libmouse_passthrough.windows.template_debug.x86_64.dll "..\..\transparent-pet\addons\mouse_passthrough\bin\"
```

### 4. 使用 CCache 加速编译（可选）

如果已安装 CCache，可大幅加速重复编译：

```powershell
# 设置 CCache 环境变量
$env:CCACHE_DIR = "$PWD\.ccache"
$env:CC = "ccache cl"
$env:CXX = "ccache cl"

# 然后正常构建
scons
```

## 三+、多设备编译加速体系

本项目配置了 Windows 专属的编译加速体系，主要特性：

### 核心特性

1. **预编译 godot-cpp**：通过 Git LFS 托管，多设备复用，避免重复编译
2. **SCons 默认配置固化**：Windows 默认平台、Debug 默认关闭 LTO
3. **Git LFS 支持**：大二进制文件高效管理
4. **子模块管理**：godot-cpp 作为 Git Submodule 统一版本
5. **CCache 缓存**：项目本地缓存目录，通过 Git LFS 共享

### 多设备协作流程

1. **主设备**：首次预编译 godot-cpp 并提交到 Git LFS
2. **其他设备**：克隆项目后直接使用，无需编译 godot-cpp
3. **日常开发**：仅编译业务代码，享受秒级增量编译

详细说明请参考 [GitSubmodule操作指南.md](GitSubmodule操作指南.md)。

## 四、构建配置说明

### 1. SConstruct 文件解析

`gdextension/mouse_passthrough_extension/SConstruct` 文件是构建配置的核心：

```python
#!/usr/bin/env python

import os

# 导入 godot-cpp 的构建配置
env = SConscript("../godot-cpp/SConstruct")

# 添加源代码目录和 godot-cpp 包含目录
env.Append(CPPPATH=["src/", "../godot-cpp/include/"])
sources = Glob("src/*.cpp")

# 构建共享库
library = env.SharedLibrary(
    "bin/libmouse_passthrough{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
    source=sources,
)

# 设置构建目标
env.NoCache(library)
Default(library)
```

### 2. GDExtension 配置文件

`gdextension/mouse_passthrough_extension/mouse_passthrough.gdextension` 文件配置了插件的加载方式：

```ini
[configuration]
entry_symbol = "mouse_passthrough_library_init"
compatibility_minimum = "4.3"

[libraries]
windows.debug.x86_64 = "res://addons/mouse_passthrough/bin/libmouse_passthrough.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://addons/mouse_passthrough/bin/libmouse_passthrough.windows.template_release.x86_64.dll"
```

## 五、常见问题及解决方案

### 1. 构建失败：找不到编译器

**原因**：MinGW-w64 未正确安装或未添加到环境变量

**解决方案**：

- 重新安装 MinGW-w64
- 确保 `mingw64/bin` 目录已添加到系统环境变量
- 重启终端或电脑使环境变量生效

### 2. 构建失败：找不到 godot-cpp 头文件

**原因**：godot-cpp 未正确构建或路径配置错误

**解决方案**：

- 先构建 godot-cpp
- 检查 SConstruct 文件中的包含路径是否正确

### 3. 插件加载失败：找不到 DLL 文件

**原因**：DLL 文件未正确复制到 Godot 项目目录

**解决方案**：

- 确认 DLL 文件已复制到 `transparent-pet/addons/mouse_passthrough/bin/` 目录
- 检查 GDExtension 配置文件中的路径是否正确

### 4. 运行时错误：未找到窗口句柄

**原因**：插件初始化时窗口尚未完全创建

**解决方案**：

- 插件初始化时不要立即尝试获取窗口句柄
- 等待窗口完全创建后再设置鼠标穿透状态

## 六、开发流程建议

1. **修改代码**：在 `gdextension/mouse_passthrough_extension/src/` 目录下修改插件代码
2. **重新构建**：运行 `scons` 命令重新构建插件
3. **部署插件**：复制生成的 DLL 文件到 Godot 项目
4. **测试插件**：在 Godot 编辑器中运行项目测试插件功能
5. **调试**：查看 Godot 输出窗口中的调试信息

## 七、构建命令速查表

| 命令                                                                                                                      | 说明                  | 适用场景  |
| ----------------------------------------------------------------------------------------------------------------------- | ------------------- | ----- |
| `scons`                                                                                                                 | 构建鼠标穿透插件（默认 Windows Debug，关闭 LTO） | 日常开发  |
| `scons -c`                                                                                                              | 清理构建产物              | 重新构建时 |
| `scons platform=windows target=release`                                                                                 | 构建 Windows Release 版本 | 正式发布  |
| `cd gdextension; python build.py`                                                                                       | 一键构建和部署 | 日常开发  |
| `git submodule update --remote`                                                                                         | 更新子模块到最新版本 | 升级依赖  |
| `git lfs pull`                                                                                                          | 拉取 LFS 大文件 | 首次克隆后 |
| `git clone --recurse-submodules 你的仓库地址`                                                                              | 克隆项目并初始化子模块 | 新设备准备 |

## 八、版本控制建议

### 1. 版本管理规则

- **Git Submodule**：godot-cpp 作为子模块统一管理版本
- **Git LFS**：预编译的 godot-cpp 库文件通过 LFS 托管
- **业务代码**：正常 Git 版本管理

### 2. .gitignore 配置

本项目已配置好合理的 .gitignore 规则：
- 忽略业务代码编译产物
- 忽略临时文件
- 保留 godot-cpp 预编译库（通过 Git LFS 管理）

### 3. Git 日常操作

```bash
# 正常提交代码
git add .
git commit -m "更新说明"
git push

# 更新子模块
git submodule update --remote
git add gdextension/godot-cpp
git commit -m "更新 godot-cpp"

# 拉取代码并同步子模块
git pull --recurse-submodules
```

### 4. 新设备初始化流程

1. 克隆项目：`git clone --recurse-submodules 你的仓库地址`
2. 拉取 LFS 文件：`git lfs pull`
3. 直接编译业务代码：`cd gdextension/mouse_passthrough_extension; scons`
4. 无需编译 godot-cpp（已预编译好）

## 九、总结

GDExtension 是 Godot 4 引入的一种扩展机制，允许使用 C++ 编写高性能的插件。本项目的鼠标穿透插件就是使用 GDExtension 实现的，通过 Windows API 实现了窗口的鼠标穿透功能。

构建流程虽然步骤较多，但只要按照本文档的说明一步步操作，就能成功构建和部署插件。如果遇到问题，请参考本文档的「常见问题及解决方案」部分，或查阅 Godot 官方文档。

***

**注意**：本文档适用于本项目的特定结构，其他项目可能需要根据实际情况进行调整。
