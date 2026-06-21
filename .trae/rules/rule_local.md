---
alwaysApply: true
---

## 项目特定规则（本文件只记录"这一个项目"独有的信息）

> 通用规则、模块化架构、Git 工作流、命令行环境规范等跨项目可复用的内容，均记录在同目录下的 `rules_common.md` 中。两份文件均设置 `alwaysApply: true`，共同生效。

**项目身份：**
- 项目名称：**Project Astra**
- 项目类型：**桌宠（Tabletop Pet / Desktop Pet）**
- Godot 根目录名：**transparent-pet**
- 本地 Godot 调试路径：**`F:\SteamLibrary\steamapps\common\Godot Engine`**

**开发环境：**
- 测试框架：**GdUnit4**
- 目标平台：**Windows / Web**
- CI/CD 平台：**GitHub Actions**
- Git 主开发分支：**dev/fan**

**模块现状：**
- 已存在模块：当前处于早期阶段，尚未建立完整的 `modules/xxx` 目录结构
- 建议新增模块：`modules/pet`（宠物核心行为与状态机）、`modules/interaction`（桌面交互/拖拽/点击）、`modules/ui`（宠物 HUD / 状态展示）、`modules/inventory`（道具系统，如喂食/换装）

**可选增强：**
- 向量知识库 / 错误记忆：已启用（同目录 `CI-DI.md` 与 `issues.md` 共同维护错误记忆与向量搜索）

**本文件维护原则：**
- 只写"这个项目独有的信息"，不重复 rules_common.md 中已有的内容。
- 当项目新增模块、变更目标平台、切换 CI 工具时，**在本文件追加或修改对应条目**。
- 当 rules_common.md 有新版时（例如升级了模块化架构规范），**把新版文件复制过来覆盖即可**，本文件不受影响。
