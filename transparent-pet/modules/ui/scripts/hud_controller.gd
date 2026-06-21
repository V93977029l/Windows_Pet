extends Node

## ============================================================================
## modules/ui/scripts/hud_controller.gd — 宠物 HUD（占位实现）
## ============================================================================
## 【架构定位】
##   占位 HUD，只维护"可见状态"与"提示文本"两个字段，
##   通过信号对外发布变化，不依赖任何具体 UI 节点。
##
##   将来在 modules/ui/scenes/ 下补好 hud.tscn 后，
##   在此类中加入对场景节点的引用即可，其余模块无变动。
## ============================================================================

signal visibility_changed(visible: bool)
signal hint_changed(text: String)

## 当前宠物节点引用（由 init() 注入）
var _pet_node: Node = null

## HUD 是否可见（占位状态）
var _visible: bool = true:
	set(v):
		_visible = v
		visibility_changed.emit(v)

## 当前提示文本（占位状态）
var _hint: String = "":
	set(v):
		_hint = v
		hint_changed.emit(v)

## ============================================================================
## 生命周期与初始化
## ============================================================================

func _ready() -> void:
	pass


## 由 pet.gd 在启动时调用，注入宠物节点以便读取状态
func init(pet_node: Node) -> void:
	_pet_node = pet_node
	print("[HUD] 初始化完成（占位版本）")


## ============================================================================
## 公共 API
## ============================================================================

func show() -> void:
	_visible = true


func hide() -> void:
	_visible = false


func set_hint(text: String) -> void:
	_hint = text


## 手动刷新信号（通常在宠物状态变更后调用一次）
func refresh() -> void:
	visibility_changed.emit(_visible)
	hint_changed.emit(_hint)
