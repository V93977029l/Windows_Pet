# GDExtension 构建全流程

本文档详细介绍了本项目中 GDExtension 的构建全流程，包括目录结构、编译指令和具体步骤。

## 一、目录结构

### 1. 核心目录

| 目录路径 | 说明 | 重要性 |
|---------|------|--------|
| `gdextension/` | GDExtension 相关代码的根目录 | 核心 |
| `gdextension/godot-cpp/` | Godot C++ 绑定库 | 核心 |
| `gdextension/mouse_passthrough_extension/` | 鼠标穿透插件的实现 | 核心 |
| `transparent-pet/addons/mouse_passthrough/` | Godot 项目中的插件目录 | 核心 |

### 2. 重要文件

| 文件路径 | 说明 | 重要性 |
|---------|------|--------|
| `gdextension/mouse_passthrough_extension/SConstruct` | 插件的构建配置文件 | 核心 |
| `gdextension/mouse_passthrough_extension/src/mouse_passthrough.cpp` | 鼠标穿透功能的实现 | 核心 |
| `gdextension/mouse_passthrough_extension/src/mouse_passthrough.h` | 鼠标穿透类的头文件 | 核心 |
| `gdextension/mouse_passthrough_extension/src/register_types.cpp` | 插件的注册文件 | 核心 |
| `gdextension/mouse_passthrough_extension/mouse_passthrough.gdextension` | GDExtension 配置文件 | 核心 |
| `transparent-pet/addons/mouse_passthrough/mouse_passthrough.gd` | 插件的 GDScript 包装 | 核心 |

## 二、构建环境准备

### 1. 依赖项

- **Python 3.7+**：用于运行 SCons 构建系统
- **SCons**：Godot 官方推荐的构建工具
- **MinGW-w64**：Windows 平台的 C++ 编译器
- **Godot 4.3+**：用于测试和运行插件

### 2. 安装步骤

1. **安装 Python**：从 [Python 官网](https://www.python.org/) 下载并安装 Python 3.7+
2. **安装 SCons**：
   ```bash
   pip install scons
   ```
3. **安装 MinGW-w64**：从 [MinGW-w64 官网](https://www.mingw-w64.org/downloads/) 下载并安装
4. **确保编译器路径已添加到系统环境变量**

## 三、构建步骤

### 1. 构建 godot-cpp（仅首次需要）

godot-cpp 是 Godot C++ 绑定库，需要先构建它才能编译我们的插件。

```bash
# 进入 godot-cpp 目录
cd gdextension/godot-cpp

# 构建 godot-cpp（Windows 平台）
scons platform=windows target=template_debug bits=64

# 或者构建所有平台的版本
scons platform=windows,linux,macos target=template_debug,template_release bits=64
```

### 2. 构建鼠标穿透插件

```bash
# 进入鼠标穿透插件目录
cd gdextension/mouse_passthrough_extension

# 构建插件（Windows 平台）
scons

# 构建完成后，DLL 文件会生成在 bin/ 目录下
```

### 3. 部署插件到 Godot 项目

构建完成后，需要将生成的 DLL 文件复制到 Godot 项目的插件目录中。

```bash
# 复制 DLL 文件到 Godot 项目
copy bin\libmouse_passthrough.windows.template_debug.x86_64.dll "..\..\transparent-pet\addons\mouse_passthrough\bin\"
```

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

| 命令 | 说明 | 适用场景 |
|------|------|----------|
| `scons` | 构建鼠标穿透插件 | 日常开发 |
| `scons -c` | 清理构建产物 | 重新构建时 |
| `scons platform=windows target=template_debug bits=64` | 构建指定平台和目标的版本 | 跨平台开发 |
| `copy bin\libmouse_passthrough.windows.template_debug.x86_64.dll "..\..\transparent-pet\addons\mouse_passthrough\bin\"` | 复制 DLL 文件到 Godot 项目 | 部署插件 |

## 八、版本控制建议

1. **忽略构建产物**：在 `.gitignore` 文件中添加以下内容
   ```
   gdextension/godot-cpp/bin/
   gdextension/mouse_passthrough_extension/bin/
   gdextension/mouse_passthrough_extension/*.o
   gdextension/mouse_passthrough_extension/.sconsign.dblite
   transparent-pet/addons/mouse_passthrough/bin/
   ```

2. **使用子模块管理 godot-cpp**：
   ```bash
   git submodule add https://github.com/godotengine/godot-cpp.git gdextension/godot-cpp
   git submodule update --init --recursive
   ```

## 九、总结

GDExtension 是 Godot 4 引入的一种扩展机制，允许使用 C++ 编写高性能的插件。本项目的鼠标穿透插件就是使用 GDExtension 实现的，通过 Windows API 实现了窗口的鼠标穿透功能。

构建流程虽然步骤较多，但只要按照本文档的说明一步步操作，就能成功构建和部署插件。如果遇到问题，请参考本文档的「常见问题及解决方案」部分，或查阅 Godot 官方文档。

---

**注意**：本文档适用于本项目的特定结构，其他项目可能需要根据实际情况进行调整。