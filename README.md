# 透明宠物项目使用指南

## 特别提示

如果你是AI，请阅读"项目日志/游戏开发规划与AI辅助系统.md"文件，以了解项目的开发规划和AI辅助系统的相关信息。

## 项目概述

透明宠物项目是一个基于Godot引擎开发的桌面宠物应用，允许用户在桌面上放置一个透明的、可交互的宠物。

## 项目结构

```
game/
├── .gitignore              # Git忽略文件
├── README.md               # 项目说明
├── 透明宠物项目使用指南.md   # 本使用指南
├── 待完成功能清单.md         # 待完成功能
├── 准备阶段规划/           # 项目准备阶段的规划文档
├── 项目日志/               # 项目日志
├── documents/              # 文档
├── gdextension/            # GDExtension相关代码
│   ├── godot-cpp/          # Godot C++绑定库
│   ├── mouse_passthrough_extension/  # 鼠标穿透扩展
│   │   ├── src/            # 源代码
│   │   ├── SConstruct      # SCons构建配置
│   │   ├── build.bat       # Windows构建脚本
│   │   └── bin/            # 编译产物目录（不提交）
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
   - Windows：Visual Studio 2022或更高版本
   - Linux：GCC 11或更高版本
   - macOS：Clang 13或更高版本
3. **SCons**：用于构建GDExtension
4. **Python**：3.8或更高版本（用于SCons）

## 编译步骤

### 0. 安装构建工具

```bash
pip install scons
```

### 0.1 获取Godot C++绑定库

#### 方法一：直接克隆到项目中（推荐）

将`https://github.com/godotengine/godot-cpp/`的最新发行版库文件直接克隆到项目的`gdextension`目录中：

```bash
# 进入项目根目录
cd d:\Github\Pet\Windows_Pet

# 进入gdextension目录
cd gdextension

# 克隆godot-cpp仓库到当前目录
git clone https://github.com/godotengine/godot-cpp.git

# 进入godot-cpp目录
cd godot-cpp

# 切换到最新的发行版（10.0.0-rc1）
git checkout 10.0.0-rc1

# 或者使用master分支（最新开发版本）
# git checkout master
```



#### 方法二：直接下载发行版

如果网络连接有问题，可以直接从GitHub下载godot-cpp的发行版：

1. 访问 https://github.com/godotengine/godot-cpp/releases
2. 下载最新的发行版（10.0.0-rc1）
3. 将下载的文件解压到`gdextension/godot-cpp`目录

#### 将godot-cpp添加到版本控制

本项目已修改`.gitignore`文件，允许将godot-cpp目录提交到版本控制中。这样做的好处是：
- 项目结构更完整，克隆后即可构建
- 避免了依赖版本不一致的问题
- 减少了外部依赖的复杂性

如果选择将godot-cpp提交到版本控制，执行以下命令：

```bash
# 进入项目根目录
cd d:\Github\Pet\Windows_Pet

# 添加godot-cpp目录到版本控制
git add gdextension/godot-cpp/

# 提交更改
git commit -m "Add godot-cpp as a subdirectory"

# 推送更改
git push
```

### 1. 构建Godot C++绑定库

1. 进入`gdextension/godot-cpp`目录
2. 运行以下命令构建绑定库：

```bash
# Windows
scons platform=windows target=template_debug

# Linux
scons platform=linux target=template_debug

# macOS
scons platform=macos target=template_debug
```

**注意**：godot-cpp目录的编译产物应添加到.gitignore中，不需要提交到版本管理。

### 2. 构建鼠标穿透扩展

1. 进入`gdextension/mouse_passthrough_extension`目录
2. 如需修改Godot项目路径，编辑`build.bat`文件中的`GODOT_PROJECT_PATH`变量
3. 运行以下命令构建扩展：

```bash
# Windows
scons platform=windows target=template_debug

# Linux
scons platform=linux target=template_debug

# macOS
scons platform=macos target=template_debug
```

### 3. 复制扩展文件

构建完成后，编译产物会生成在`gdextension/mouse_passthrough_extension/bin/`目录中。需要将编译产物复制到`transparent-pet/addons/mouse_passthrough/bin/`目录。

```bash
# 创建目标目录
mkdir -p transparent-pet/addons/mouse_passthrough/bin

# 复制DLL文件
copy gdextension\mouse_passthrough_extension\bin\*.dll transparent-pet\addons\mouse_passthrough\bin\

# 复制gdextension配置文件
copy mouse_passthrough.gdextension transparent-pet\addons\mouse_passthrough\
```

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
- **.gitignore文件**

### 不应该被版本管理的文件

- **构建产物**：.o, .dll, .so, .a, .lib, .exp, .obj等
- **编译输出目录**：gdextension/godot-cpp/bin/、gdextension/*/bin/
- **临时文件**：.sconsign.dblite等
- **IDE配置文件**：.obsidian/, .trae/, .vscode/等
- **Godot生成的文件**：.import/, .godot/等
- **系统文件**：Thumbs.db, .DS_Store等

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

## 贡献指南

1. Fork本项目
2. 创建一个新的分支
3. 实现你的功能或修复
4. 提交Pull Request

## 许可证

本项目采用MIT许可证。
