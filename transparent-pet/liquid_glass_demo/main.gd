# ============================================================================
# 文件：main.gd
# ============================================================================
# 作用：
#     本文件是"液态玻璃演示"(Liquid Glass Demo) 场景的**主入口脚本**。
#     它挂载在场景的根节点上（`extends Node2D`），负责：
#       1. 协调渲染器与控制面板之间的交互。
#       2. 处理用户输入事件（鼠标拖拽、键盘快捷键）。
#       3. 管理场景的全局状态（如控制面板可见性）。
#
# 设计模式：
#     - 【中介者模式 (Mediator Pattern)】：`main.gd` 充当渲染器和控制面板
#       之间的中介，协调两者的通信。渲染器管理视觉输出，控制面板管理参数输入，
#       两者不直接通信。主脚本将用户输入路由到渲染器。
#     - 【输入处理管线 (Input Pipeline)】：`_input()` 方法实现了一个迷你
#       输入管线：先分类事件类型（鼠标移动 / 鼠标按钮 / 键盘），然后分发到
#       对应的处理逻辑。
#
# 架构说明：
#     ┌──────────────────────────────────┐
#     │           main.gd (根节点)        │
#     │                                   │
#     │  ┌─────────────┐ ┌─────────────┐  │
#     │  │  渲染器      │ │  控制面板    │  │
#     │  │ Renderer    │ │ ControlPanel│  │
#     │  └──────┬──────┘ └──────┬──────┘  │
#     │         │               │          │
#     │         ▼               ▼          │
#     │  ┌─────────────┐ ┌─────────────┐  │
#     │  │ 管理器      │ │  滑块/控件   │  │
#     │  │ ItemManager │ │  (UI)       │  │
#     │  └─────────────┘ └─────────────┘  │
#     └──────────────────────────────────┘
#
#     用户输入 → main._input() → item_manager 或 控制面板可见性
#     控制面板 → 直接修改 renderer 属性
#     渲染器   → 从 item_manager 读取数据打包给着色器
# ============================================================================

# ============================================================================
# 类：main (继承 Node2D)
# ============================================================================
# 职责：
#     - 场景入口，协调子节点。
#     - 处理鼠标和键盘输入。
#     - 初始化控制面板为隐藏状态。
#     - 初始化鼠标位置（防止初始帧鼠标在视口外导致渲染异常）。
# ============================================================================
extends Node2D

# ---------------------------------------------------------------------------
# @onready 节点引用
# ---------------------------------------------------------------------------

# renderer (LiquidGlassRenderer)
#     对渲染器子节点的引用。通过 `$LiquidGlassRenderer` 路径获取。
#     所有渲染相关的操作（设置着色器 uniform、更新物品数据）都通过此引用。
@onready var renderer: Node2D = $LiquidGlassRenderer

# control_panel (PanelContainer)
#     对控制面板子节点的引用。通过 `$ControlPanel` 路径获取。
#     控制面板包含折射、高光、模糊、色调等参数的实时调节控件。
@onready var control_panel: PanelContainer = $ControlPanel

# ---------------------------------------------------------------------------
# 成员变量
# ---------------------------------------------------------------------------

# is_dragging (bool)
#     标记当前是否处于拖拽状态。
#     true  → 鼠标左键已按下且命中了一个物品，正在拖拽中。
#     false → 鼠标左键未按下或拖拽已结束。
#     用于在 `_input()` 中区分"开始拖拽"和"持续拖拽"两种状态。
var is_dragging = false

# ============================================================================
# 方法：_ready()
# ============================================================================
# 参数：无
# 返回值：无
#
# 核心逻辑：
#     1. 启用输入处理（`set_process_input(true)`），确保 `_input()` 方法
#        能接收到原始输入事件。
#     2. 隐藏控制面板，使默认界面干净整洁。用户按空格键可切换显示。
#     3. 初始化鼠标位置相关 uniform：
#        - `set_mouse_position(viewport_size / 2)`：将鼠标位置初始化到
#          视口中心，防止着色器中使用的鼠标位置在首帧为 Vector2.ZERO，
#          导致折射/高光计算产生异常偏移。
#        - `set_mouse_spring(viewport_size / 2)`：将鼠标弹簧位置也初始化
#          到视口中心。弹簧位置用于实现平滑的鼠标跟踪效果（着色器中使用
#          `mix()` 或 `lerp()` 实现惯性追踪）。
#
# DPR 说明：
#     `content_scale_factor`（设备像素比/DPR）在高 DPI 显示器上大于 1（如
#     Retina 屏幕上为 2）。视口逻辑尺寸与物理像素尺寸的比例通过 DPR 关联。
#     此处的 viewport_size 已乘以 DPR，表示着色器中实际使用的物理像素分辨率。
# ============================================================================
func _ready():
	set_process_input(true)
	control_panel.visible = false

	if renderer:
		var dpr: float = get_tree().root.content_scale_factor
		var viewport_size = Vector2(get_viewport_rect().size.x * dpr, get_viewport_rect().size.y * dpr)
		renderer.set_mouse_position(viewport_size / 2)
		renderer.set_mouse_spring(viewport_size / 2)

# ============================================================================
# 方法：_input(event: InputEvent)
# ============================================================================
# 参数：
#     event (InputEvent) - Godot 引擎分发的输入事件对象。
#                          可能是鼠标移动、鼠标按钮、键盘等任意类型。
#
# 返回值：无
#
# 核心逻辑（输入事件分发管线）：
#     本方法根据事件类型将输入分为三条处理路径：
#
#     【路径1】鼠标移动事件 (InputEventMouseMotion)
#       - 在拖拽状态下（is_dragging == true），持续更新被拖拽物品的位置。
#       - 同时更新渲染器中的鼠标位置和弹簧位置 uniform。
#       - 更新时使用物理像素坐标（乘以 DPR）。
#
#     【路径2】鼠标左键事件 (InputEventMouseButton, MOUSE_BUTTON_LEFT)
#       - 按下时（event.pressed）：
#         → 通过 item_manager.start_drag() 尝试开始拖拽。
#         → 返回值为 true 表示命中了物品，将 is_dragging 设为 true。
#         → 更新鼠标位置 uniform。
#       - 释放时（!event.pressed）：
#         → 停止拖拽（is_dragging = false）。
#         → 调用 item_manager.end_drag() 清除拖拽状态。
#
#     【路径3】键盘事件 (InputEventKey)
#       - 空格键（KEY_SPACE）按下时：切换控制面板的可见性。
#         这是一个开/关型切换（toggle），方便用户随时调出参数面板。
#
# 关于 DPR 坐标转换的说明：
#     鼠标事件的 `position` 字段是逻辑像素坐标。而着色器中所有计算基于
#     物理像素（因为 SubViewport 的尺寸已乘以 DPR）。因此在传递鼠标位置
#     到渲染器之前，需要乘以 `content_scale_factor` 进行坐标换算。
# ============================================================================
func _input(event: InputEvent):
	var dpr: float = get_tree().root.content_scale_factor

	if event is InputEventMouseMotion:
		if is_dragging and renderer:
			var item_manager = renderer.get_item_manager()
			item_manager.update_drag(event.position * dpr)

			renderer.set_mouse_position(event.position * dpr)
			renderer.set_mouse_spring(event.position * dpr)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if renderer:
				var item_manager = renderer.get_item_manager()
				is_dragging = item_manager.start_drag(event.position * dpr)

				renderer.set_mouse_position(event.position * dpr)
				renderer.set_mouse_spring(event.position * dpr)
		else:
			is_dragging = false
			if renderer:
				var item_manager = renderer.get_item_manager()
				item_manager.end_drag()

	elif event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed:
			control_panel.visible = !control_panel.visible