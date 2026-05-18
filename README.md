# 透明宠物项目使用指南

## 特别提示

如果你是AI，请阅读"项目日志/游戏开发规划与AI辅助系统.md"文件，以了解项目的开发规划和AI辅助系统的相关信息。

## 项目概述

透明宠物项目是一个基于Godot引擎开发的桌面宠物应用，允许用户在桌面上放置一个透明的、可交互的宠物。

## 项目结构

```
game/
├── .gitignore              # Git忽略文件
├── .gitattributes          # Git属性配置（LFS支持）
├── .gitmodules             # Git子模块配置
├── README.md               # 项目说明
├── 透明宠物项目使用指南.md   # 本使用指南
├── 待完成功能清单.md         # 待完成功能
├── 准备阶段规划/           # 项目准备阶段的规划文档
├── 项目日志/               # 项目日志
├── documents/              # 文档
├── gdextension/            # GDExtension相关代码
│   ├── godot-cpp/          # Godot C++绑定库（Git子模块）
│   ├── mouse_passthrough_extension/  # 鼠标穿透扩展
│   │   ├── src/            # 源代码
│   │   ├── SConstruct      # SCons构建配置
│   │   ├── build.bat       # Windows构建脚本
│   │   └── bin/            # 编译产物目录
│   └── simple_extension/   # 简单扩展
└── transparent-pet/        # 透明宠物项目
    ├── addons/             # 插件
    ├── node_2d.tscn        # 场景文件
    ├── pet.gd              # 宠物脚本
    ├── pet_drag.gd         # 宠物拖拽脚本
    ├── pet_mouse_manager.gd # 宠物鼠标管理器脚本
    └── project.godot       # Godot项目配置
```

## 环境要求

1. **Godot引擎**：4.3或更高版本
2. **C++编译器**：
   - Windows：Visual Studio 2022或更高版本（推荐）
3. **SCons**：用于构建GDExtension
4. **Python**：3.8或更高版本（用于SCons）
5. **Git & Git LFS**：版本控制和大文件管理
   - 已启用 Git LFS 管理预编译的 godot-cpp 绑定库

## 编译步骤

### 0. 安装构建工具

```bash
pip install scons
```

### 0.1 初始化项目子模块（首次克隆后）

本项目使用 Git Submodule 管理 godot-cpp 依赖库，首次克隆后需初始化：

```bash
# 方式一：克隆时自动初始化（推荐）
git clone --recurse-submodules 你的仓库地址

# 方式二：已克隆主项目后手动初始化
git submodule init
git submodule update
```

**重要**：godot-cpp 预编译库已通过 Git LFS 托管，拉取时确保启用了 Git LFS。

### 0.2 拉取 LFS 文件（如果需要）

```bash
git lfs pull
```

### 1. 预编译 Godot C++ 绑定库（首次或需要重新编译时）

godot-cpp 预编译库已通过 Git LFS 托管，通常无需手动编译。如需重新编译：

```bash
# 进入 godot-cpp 目录
cd gdextension/godot-cpp

# Windows Debug 模式（关闭 LTO 加速开发）
scons platform=windows target=debug -j12 lto=no

# Windows Release 模式
scons platform=windows target=release -j12 lto=full
```

### 2. 构建鼠标穿透扩展

1. 进入`gdextension/mouse_passthrough_extension`目录
2. 如需修改Godot项目路径，编辑`build.bat`文件中的`GODOT_PROJECT_PATH`变量
3. 运行以下命令构建扩展：

```bash
# Windows Debug 模式（开发时推荐，关闭 LTO）
scons

# 或手动指定参数
scons platform=windows target=debug -j12 lto=no
```

### 3. 复制扩展文件

构建完成后，编译产物会生成在`gdextension/mouse_passthrough_extension/bin/`目录中。

可直接使用 `gdextension/build.py` 脚本一键构建并部署：

```bash
cd gdextension
python build.py
```

或者手动部署：

```bash
# 创建目标目录
mkdir -p transparent-pet/addons/mouse_passthrough/bin

# 复制DLL文件
copy gdextension\mouse_passthrough_extension\bin\*.dll transparent-pet\addons\mouse_passthrough\bin\

# 复制gdextension配置文件
copy mouse_passthrough.gdextension transparent-pet\addons\mouse_passthrough\
```

## 编译加速体系说明

本项目已配置 Windows 专属的编译加速体系，主要特性：

1. **预编译 godot-cpp**：通过 Git LFS 托管，多设备复用，避免重复编译
2. **SCons 默认配置固化**：Windows 默认平台、Debug 默认关闭 LTO
3. **Git LFS 支持**：大二进制文件高效管理
4. **子模块管理**：godot-cpp 作为 Git Submodule 统一版本

详细说明请参考：
- [GitSubmodule操作指南.md](documents/GitSubmodule操作指南.md) - 子模块管理指南
- [GDExtension构建全流程.md](documents/GDExtension构建全流程.md) - 完整构建流程文档

### 4. 配置gdextension文件

确保`transparent-pet/addons/mouse_passthrough/mouse_passthrough.gdextension`文件中的库路径配置正确：

```ini
[libraries]
windows.x86_64 = "res://addons/mouse_passthrough/bin/libmouse_passthrough.windows.template_debug.x86_64.dll"
windows.template_debug.x86_64 = "res://addons/mouse_passthrough/bin/libmouse_passthrough.windows.template_debug.x86_64.dll"
windows.template_release.x86_64 = "res://addons/mouse_passthrough/bin/libmouse_passthrough.windows.template_release.x86_64.dll"
```

## 详细构建流程

如果需要更详细的GDExtension构建流程，请参考[GDExtension构建全流程.md](documents/GDExtension构建全流程.md)文件，该文件包含了：
- 详细的目录结构说明
- 构建环境的准备步骤
- 完整的构建命令
- 常见问题及解决方案
- 开发流程建议
- 构建命令速查表
- 版本控制建议

## 运行项目

1. 打开Godot引擎
2. 导入`transparent-pet`目录作为项目
3. 运行场景`node_2d.tscn`或`main.tscn`

## 功能说明

### 宠物功能

- **移动**：宠物会随机移动
- **拖拽**：可以通过鼠标拖拽宠物
- **鼠标穿透**：宠物不会阻止鼠标点击其下方的内容

### 扩展功能

- **鼠标穿透**：允许鼠标点击宠物下方的窗口
- **简单扩展**：提供一些基本功能示例

## 开发指南

### 添加新功能

1. 在`transparent-pet`目录中创建新的脚本或场景
2. 修改现有的脚本文件以添加新功能
3. 如果需要C++功能，修改`gdextension`目录中的扩展代码并重新构建

### 调试

1. 使用Godot的内置调试器调试GDScript代码
2. 使用C++编译器的调试工具调试C++扩展代码

## 版本管理

### 应该被版本管理的文件

- **源代码文件**：.cpp, .h, .gd, .tscn, .gdextension等
- **项目配置文件**：project.godot, SConstruct等
- **文档文件**：.md文件
- **插件配置文件**：plugin.cfg等
- **图标文件**：icon.svg等
- **.gitignore、.gitattributes、.gitmodules文件**

### 不应该被版本管理的文件

- **业务代码构建产物**：gdextension/mouse_passthrough_extension/bin/、.o, .obj等
- **临时文件**：.sconsign.dblite等
- **IDE配置文件**：.obsidian/, .trae/, .vscode/等
- **Godot生成的文件**：.import/, .godot/等
- **系统文件**：Thumbs.db, .DS_Store等

### Git LFS 托管的文件

- **godot-cpp/bin/**：预编译的 Godot C++ 绑定库（通过 Git LFS 管理）

## 常见问题

### 扩展构建失败

- 确保已安装正确版本的C++编译器
- 确保已安装SCons和Python
- 检查Godot C++绑定库是否已正确构建

### 鼠标穿透不工作

- 确保已正确构建并复制了鼠标穿透扩展
- 检查`mouse_passthrough.gdextension`文件是否正确配置
- 确认gdextension文件中包含了`windows.x86_64`键

### 宠物不显示

- 确保场景文件`node_2d.tscn`或`main.tscn`已正确加载
- 检查宠物脚本是否有错误

### Git LFS 文件未正确拉取

- 确保已安装 Git LFS：`git lfs install`
- 执行 `git lfs pull` 拉取大文件

## 贡献指南

1. Fork本项目
2. 创建一个新的分支
3. 实现你的功能或修复
4. 提交Pull Request

## 许可证

本项目采用MIT许可证。
