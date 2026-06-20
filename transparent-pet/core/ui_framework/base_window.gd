class_name BasePetWindow
extends Window

## ============================================================================
## core/ui_framework/base_window.gd — 所有桌宠设置窗口的基类
## ============================================================================
## 提供统一的窗口初始化、pet_node 注入和关闭行为。
## 子类只需覆盖 _setup_ui() 和实现自己的 UI 逻辑。
## ============================================================================

var pet_node: Node2D = null
var _pending_setup: bool = false


## 设置宠物节点引用（通常在实例化后立即调用）
func set_pet_node(pet: Node2D):
	pet_node = pet
	if pet_node:
		_pending_setup = true


func _ready():
	transparent = false
	always_on_top = true
	close_requested.connect(_on_close)

	if _pending_setup:
		_setup_ui()
		_pending_setup = false

	visible = true
	await get_tree().process_frame
	grab_focus()


## 子类覆盖此方法以初始化 UI 连接和加载配置
func _setup_ui():
	pass


func _on_close():
	queue_free()
