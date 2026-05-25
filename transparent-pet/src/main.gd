## Main - 桌宠主控制器（根节点）
## =========================================================================
## 【架构定位】
##   本类是整个桌宠应用的"大脑"和"调度中心"，继承自 Node2D，
##   作为场景树的根节点运行。它负责初始化所有子系统（渲染器、
##   材质管理器、鼠标管理器、配置管理器、拖拽控制器等），并协调
##   它们之间的交互。
##
## 【设计模式】
##   采用"组合模式"和"门面模式"的混合架构：
##   - 组合模式：各子系统作为本节点的子组件，通过组合实现功能
##   - 门面模式：对外部（场景树、引擎回调）提供统一的接口，
##     隐藏了内部复杂的子系统交互细节
##
## 【生命周期】
##   1. _ready(): 初始化所有子系统、注册回调、加载配置
##   2. _input(event): 处理输入事件（拖拽、按键等）
##   3. _process(delta): 每帧更新（拖拽位置、鼠标穿透等）
##
## 【子系统清单】
##   - LiquidGlassRenderer: 场景中的渲染节点（SVG渲染效果）
##   - ControlPanel: 场景中的控制面板（调试/开发用）
##   - 拖拽系统: 通过 DragController 实现精灵拖拽
##   - 鼠标交互: 通过 MouseManager 实现像素级碰撞和穿透切换
## =========================================================================

extends Node2D

## 液体玻璃渲染器引用（场景中的子节点）
## 负责实现史莱姆的动态材质渲染效果
@onready var renderer: Node2D = $LiquidGlassRenderer

## 控制面板引用（场景中的子节点）
## 包含调试/开发用的UI控件，默认隐藏
@onready var control_panel: PanelContainer = $ControlPanel

## 是否正在拖拽对象
## true: 鼠标左键按下并拖动了某个可拖拽的对象
## false: 空闲状态
var is_dragging = false

## 被拖拽对象的索引（在渲染器的item管理器中的位置）
## -1 表示没有正在拖拽的对象
## >= 0 表示正在拖拽的对象在items数组中的索引
var dragged_item_index = -1

## 拖拽偏移向量（对象位置与鼠标位置的差值）
## 用于在拖拽过程中保持对象与鼠标的相对位置不变
## 计算公式: drag_offset = item.position - event.position（按下时的值）
var drag_offset = Vector2.ZERO


## 节点就绪回调（Godot生命周期方法）
## 【核心逻辑】
##   1. 启用输入处理（set_process_input(true)使 _input() 生效）
##   2. 隐藏控制面板（默认不可见，按空格键切换显示）
##   3. 初始化渲染器的鼠标位置参数（设置为原点，避免初始帧出现异常值）
## 【为什么隐藏控制面板？】
##   控制面板是开发调试用的，最终用户不应看到。
##   通过空格键可以随时切换显示，方便开发时调试。
func _ready():
	set_process_input(true)
	control_panel.visible = false
	
	if renderer:
		renderer.set_mouse_position(Vector2.ZERO)
		renderer.set_mouse_spring(Vector2.ZERO)


## 输入事件处理（Godot生命周期回调）
## 【参数】
##   event: InputEvent - 由引擎传入的输入事件对象
## 【核心逻辑】
##   处理三种类型的输入事件：
##
##   ———— 鼠标移动事件 (InputEventMouseMotion) ————
##   1. 如果正在拖拽对象 → 更新被拖拽对象的位置
##      new_position = event.position + drag_offset
##   2. 更新渲染器的鼠标位置参数（用于材质的鼠标交互效果）
##
##   ———— 鼠标按键事件 (InputEventMouseButton, 左键) ————
##   按下时：
##     通过渲染器的item管理器检测鼠标点击位置的对象
##     如果命中 → 开始拖拽，计算并保存拖拽偏移
##   释放时：
##     清除拖拽状态
##
##   ———— 键盘事件 (InputEventKey, 空格键) ————
##   按下空格键 → 切换控制面板的可见性
##
## 【为什么使用 event.position 而不是 get_global_mouse_position()？】
##   event.position 是事件发生时的准确坐标，与事件帧同步。
##   get_global_mouse_position() 是调用时刻的实时坐标，可能已有微小偏移。
func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		# 拖拽中的对象跟随鼠标移动
		if is_dragging and dragged_item_index >= 0:
			var item_manager = renderer.get_item_manager()
			var items = item_manager.get_items()
			if dragged_item_index < items.size():
				var item = items[dragged_item_index]
				item.position = event.position + drag_offset
		
		# 更新渲染器的鼠标位置（用于Shader中的鼠标交互效果）
		if renderer:
			renderer.set_mouse_position(event.position)
			renderer.set_mouse_spring(event.position)
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 鼠标左键按下：查找被点击的对象并开始拖拽
			if renderer:
				var item_manager = renderer.get_item_manager()
				dragged_item_index = item_manager.select_item_at_position(event.position)
				if dragged_item_index >= 0:
					is_dragging = true
					var items = item_manager.get_items()
					var item = items[dragged_item_index]
					drag_offset = item.position - event.position
		else:
			# 鼠标左键释放：结束拖拽
			is_dragging = false
			dragged_item_index = -1
	
	elif event is InputEventKey:
		# 空格键：切换控制面板的可见性
		if event.keycode == KEY_SPACE and event.pressed:
			control_panel.visible = !control_panel.visible
