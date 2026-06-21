# UI 界面待办

> 所有 UI 界面相关的待办项目

---

## 待办项目

| 界面     | 用途           | 路径                         | 优先级 |
| -------- | -------------- | ---------------------------- | ------ |
| HUD 界面 | 显示提示、状态 | `modules/ui/scenes/hud.tscn` | 高     |

---

## HUD 实现步骤

### 1. 创建 HUD 场景

`modules/ui/scenes/hud.tscn`

- 根节点：`Control`（或 `CanvasLayer` + `Control`）
- 子节点：
  - `HintLabel`：`Label`，显示 `hud_controller.hint`
  - `StatusPanel`：预留显示状态（当前无状态系统，可先隐藏）

### 2. 接入到 hud_controller.gd

修改 `modules/ui/scripts/hud_controller.gd`：

- 把 `init()` 改为实例化 `hud.tscn` 并作为宠物的兄弟节点
- 绑定 `hint_changed` 信号更新 `HintLabel.text`
- 绑定 `visibility_changed` 控制整个 HUD 的 `visible`

### 3. 拖放交互

在 `pet.gd` 中：

- 拖拽开始时调用 `ui_controller.set_hint("拖拽中...")`
- 释放后清空提示
