## DragController - 拖拽控制器（RefCounted单例管理器）
## =========================================================================
## 【架构定位】
##   本类是桌宠拖拽系统的核心控制器，采用"逻辑与视图分离"的设计模式。
##   它不继承Node，而是继承RefCounted，由主节点（main.gd中的Node2D）持有
##   其实例，负责处理所有与拖拽相关的输入逻辑。
##
## 【设计模式】
##   采用"策略模式"——拖拽逻辑独立封装，不污染主节点的事件处理代码。
##   主节点只需要在_input()中调用本控制器的对应方法即可完成拖拽功能。
##
## 【核心职责】
##   1. 监听鼠标按下/释放事件，判断是否开始或结束拖拽
##   2. 计算鼠标与被拖拽精灵之间的偏移量（click_offset）
##   3. 每帧更新拖拽目标的位置
##
## 【状态管理】
##   - is_dragging: 布尔标志位，标记当前是否处于拖拽状态
##   - drag_target: 当前被拖拽的精灵节点引用
##   - click_offset: 鼠标点击位置与精灵中心点之间的像素偏移
##
## 【使用方式】
##   var controller = DragController.new()
##   controller.init(self)  # 传入主节点作为parent_node
##   在_input()中调用 controller.handle_area_input_event(event)
##   在_process()中调用 controller.update_drag()
## =========================================================================

class_name DragController
extends RefCounted

## 主节点引用（即拥有本控制器的Node2D，通常是main.gd的根节点）
## 用于获取全局鼠标位置、访问子节点等
var parent_node: Node2D

## 鼠标按下时，光标位置与精灵中心点之间的偏移量（像素，整数）
## 用于在拖拽过程中保持精灵相对鼠标的固定偏移，避免拖拽瞬间精灵"跳动"
## 例如：精灵在(100,100)、鼠标在(150,120)处按下，则click_offset为(50,20)
var click_offset: Vector2i = Vector2i.ZERO

## 当前是否处于拖拽状态（左键按下且未释放）
## true: 正在拖拽中，update_drag()会持续更新精灵位置
## false: 空闲状态，update_drag()不做任何操作
var is_dragging: bool = false

## 当前被拖拽的精灵节点（Sprite2D）
## 仅在 is_dragging == true 时有效，释放后置为 null
## 注意：这允许将来扩展为拖拽不同的精灵对象
var drag_target: Sprite2D = null


## 初始化拖拽控制器
## 【参数】
##   node: Node2D - 父节点引用，通常传入拥有本控制器的场景根节点
## 【核心逻辑】
##   保存父节点引用，该引用在整个拖拽生命周期中不变
## 【边界情况】
##   如果传入 null，handle_area_input_event() 和 update_drag() 都会安全返回
func init(node: Node2D):
	parent_node = node
	print("✅ [拖动] 拖动逻辑初始化完成")


## 处理输入事件（由父节点的_input()回调中调用）
## 【参数】
##   event: InputEvent - 输入事件对象，由Godot引擎传入
##   target_sprite: Sprite2D - 可选，指定要拖拽的目标精灵；若为null则自动获取"Slime1"子节点
## 【核心逻辑】
##   1. 检查父节点是否存在
##   2. 如果未指定target_sprite，默认获取名为"Slime1"的精灵节点
##   3. 仅响应鼠标左键事件（MOUSE_BUTTON_LEFT）
##   4. 按下时：计算偏移量 → 设置拖拽状态 → 记录拖拽目标
##   5. 释放时：清除拖拽状态
## 【为什么用click_offset而不是直接设置位置？】
##   如果不计算偏移，按下瞬间精灵会"跳"到鼠标位置，用户体验差。
##   偏移量确保了精灵始终跟随鼠标的相对位置关系不变。
## 【边界情况】
##   - parent_node 为空 → 直接返回，不做任何处理
##   - target_sprite 为 null 且子节点"Slime1"不存在 → get_node()会报错（由调用方保证节点存在）
func handle_area_input_event(event: InputEvent, target_sprite: Sprite2D = null):
	if not parent_node:
		return

	if not target_sprite:
		target_sprite = parent_node.get_node("Slime1")

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 鼠标左键按下：进入拖拽模式
			# 获取全局鼠标位置和目标精灵的全局位置，两者的差值就是偏移量
			var mouse_global: Vector2 = parent_node.get_global_mouse_position()
			var target_global: Vector2 = target_sprite.global_position
			click_offset = Vector2i(int(round(mouse_global.x - target_global.x)), int(round(mouse_global.y - target_global.y)))
			is_dragging = true
			drag_target = target_sprite
			print("[拖动] 左键按下，开始拖动，目标:", target_sprite.name, "偏移:", click_offset)
		else:
			# 鼠标左键释放：退出拖拽模式
			is_dragging = false
			drag_target = null
			print("[拖动] 左键松开，停止拖动")


## 每帧更新拖拽目标的位置（由父节点的_process()回调中调用）
## 【核心逻辑】
##   用当前全局鼠标位置减去按下时的偏移量，得到精灵应有的新位置
##   公式: new_pos = mouse_global - click_offset
##   这样保持了精灵相对于鼠标的初始偏移不变
## 【边界情况】
##   - parent_node 为空 → 安全返回
##   - !is_dragging → 安全返回（不在拖拽状态则跳过）
##   - drag_target 为 null → 安全返回（没有拖拽目标则跳过）
## 【为什么每帧都调用？】
##   鼠标移动是连续的，需要在_process()中以帧为单位持续更新位置，
##   才能实现流畅的拖拽动画效果。如果只响应鼠标移动事件，在低帧率下可能不连贯。
func update_drag():
	if not parent_node or not is_dragging or not drag_target:
		return

	var mouse_global: Vector2 = parent_node.get_global_mouse_position()
	var new_pos: Vector2 = Vector2(mouse_global.x - click_offset.x, mouse_global.y - click_offset.y)
	drag_target.global_position = new_pos
