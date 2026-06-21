class_name PetUIAPI
extends Node

## ============================================================================
## modules/ui/api.gd — UI 模块的公共接口契约
## ============================================================================
## 【架构定位】
##   本类是桌宠 UI 系统的对外契约，声明 HUD（平视显示器）
##   与其他 UI 元素的公共信号与方法。当前为占位实现：
##   只提供最基本的"显示/隐藏/更新提示文本"能力，用于
##   验证框架可用。将来加入饥饿度、心情、换装等状态时，
##   在本文件中追加对应的信号与方法即可。
## ============================================================================

## HUD 显示状态切换时触发
signal visibility_changed(visible: bool)

## HUD 提示文本更新时触发
signal hint_changed(text: String)

var _controller = null

func init(pet_node: Node):
	push_error("[PetUIAPI] init() must be implemented by ui_controller")

func show():
	push_error("[PetUIAPI] show() must be implemented by ui_controller")

func hide():
	push_error("[PetUIAPI] hide() must be implemented by ui_controller")

func set_hint(text: String):
	push_error("[PetUIAPI] set_hint() must be implemented by ui_controller")

func refresh():
	push_error("[PetUIAPI] refresh() must be implemented by ui_controller")
