# 透明宠物项目 (TransparentPet)

## 特别提示

如果你是AI，请阅读 [documents/游戏开发规划与AI辅助系统.md](documents/游戏开发规划与AI辅助系统.md) 文件，以了解项目的开发规划和AI辅助系统的相关信息。

## 项目概述

透明宠物项目是一个基于Godot引擎开发的桌面宠物应用，允许用户在桌面上放置一个透明的、可交互的史莱姆宠物。

**核心特性：**
- 无边框透明窗口，始终置顶（可开关）
- 基于像素Alpha通道的精确鼠标检测
- 系统托盘支持，最小化到托盘
- 可拖拽和抛射物理效果
- 史莱姆材质着色器效果
- SVG矢量渲染，缩放不失真
- 模块化架构设计

## 项目结构

```
game/
├── .trae/                          # Trae AI 辅助规则
├── .vscode/                        # VSCode 配置
├── documents/                      # 项目文档
│   ├── tool-guides/                # 工具指南
│   │   ├── GDExtension构建全流程.md
│   │   └── GitSubmodule操作指南.md
│   ├── 快速测试指南.md
│   ├── 桌宠开发日志.md
│   ├── 游戏开发规划与AI辅助系统.md
│   └── 项目结构总览.md
├── external/                       # 外部依赖
│   ├── godot-cpp/                  # Godot C++ 绑定库 (Git Submodule)
│   └── liquid-glass-studio/        # 液态玻璃特效参考项目
├── gdextension/                    # GDExtension 原生扩展
│   ├── mouse_passthrough_extension/
│   ├── system_tray_extension/
│   ├── liquid_glass_extension/
│   └── build.py                    # 一键构建脚本
└── transparent-pet/                # ⭐ Godot 主项目
    ├── addons/                     # 插件
    ├── assets/                     # 资源
    ├── config/                     # 配置文件
    ├── core/                       # 核心系统
    ├── modules/                    # 功能模块
    ├── prototypes/                 # 原型区
    └── project.godot
```

## 文档导航

### 游戏设计文档 (GDD)

| 文档 | 说明 |
| --- | --- |
| [GDD总览.md](docs/gdd/00-GDD总览.md) | ⭐ 设计支柱、原则、文档导航（GDD 入口） |
| [核心体验循环.md](docs/gdd/01-核心体验循环.md) | Moment/Session/Long-term 三层循环 |
| [玩家动机与画像.md](docs/gdd/02-玩家动机与画像.md) | 目标玩家、动机、混合型主次排序 |
| [机制规格/](docs/gdd/03-机制规格/) | 自主行为/情绪/互动反馈/收集解锁/自定义 5 大系统 |
| [成就与收集册.md](docs/gdd/04-成就与收集册.md) | 无货币经济下的长期目标系统 |
| [调优变量表.md](docs/gdd/05-调优变量表.md) | 全部数值假设与调优区间 |
| [新手引导流程.md](docs/gdd/06-新手引导流程.md) | 首次启动体验设计 |
| [现有功能体验规格化.md](docs/gdd/07-现有功能体验规格化.md) | 已实现功能的玩家体验规格 |

### 工程文档

| 文档 | 说明 |
| --- | --- |
| [项目结构总览.md](docs/项目结构总览.md) | 完整的项目架构和模块说明 |
| [GDExtension构建全流程.md](docs/tool-guides/GDExtension构建全流程.md) | GDExtension 编译和部署指南 |
| [GitSubmodule操作指南.md](docs/tool-guides/GitSubmodule操作指南.md) | Git Submodule 管理指南 |
| [快速测试指南.md](docs/快速测试指南.md) | 快速上手和测试流程 |
| [桌宠开发日志.md](docs/桌宠开发日志.md) | 项目开发历史记录 |

## 环境要求

1. **Godot 引擎**：4.3 或更高版本
2. **C++ 编译器**：Visual Studio 2022 或更高版本（推荐）
3. **SCons**：用于构建 GDExtension
4. **Python**：3.8 或更高版本
5. **Git & Git LFS**：版本控制和大文件管理

## 快速开始

### 1. 克隆项目

```bash
git clone --recurse-submodules 你的仓库地址
cd game
```

### 2. 构建 GDExtension

```bash
cd gdextension
python build.py
```

详细说明请参考 [GDExtension构建全流程.md](documents/tool-guides/GDExtension构建全流程.md)。

### 3. 运行项目

1. 打开 Godot 引擎
2. 导入 `transparent-pet/` 目录作为项目
3. 运行 `modules/pet/scenes/pet.tscn` 场景或按 F5

## 功能说明

### 宠物功能
- **拖拽**：按住鼠标左键可拖拽宠物
- **抛射**：快速拖拽并松开可抛出宠物，具有重力、碰撞和摩擦物理效果
- **鼠标穿透**：鼠标不在宠物上时自动穿透点击
- **动态效果**：史莱姆着色器动画（可开关）

### 设置窗口
- 按 `键（反引号）或点击系统托盘图标打开设置
- 可调整缩放、材质、置顶状态
- 抛射物理参数配置

### 系统托盘
- 左键点击：打开设置窗口
- 右键点击：弹出菜单（设置/退出）
- 支持 explorer 重启后自动恢复

## 开发指南

### 模块化架构

项目采用商业级模块化架构：
- **core/**：核心系统与基础设施（修改需谨慎）
- **modules/**：功能模块，每个模块独立
  - **pet/**：宠物主协调模块
  - **display/**：显示和渲染模块
  - **interaction/**：交互和鼠标管理
  - **effects/**：特效管理
  - **settings/**：设置界面
- **api.gd**：每个模块的公共接口契约
- **信号优先**：模块间通信优先使用信号

详细说明请参考 [项目结构总览.md](documents/项目结构总览.md)。

### 添加新功能

1. 在 `modules/` 中创建新的功能模块
2. 定义模块的 `api.gd` 接口
3. 实现功能逻辑
4. 通过信号与其他模块通信

## 版本管理

### Git 分支策略
- `dev/fan`：开发分支
- `main`：稳定分支

### 版本号
遵循语义化版本规范：`MAJOR.MINOR.PATCH`

## 常见问题

详见各文档的常见问题章节。

## 许可证

MIT License
