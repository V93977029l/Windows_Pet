extends Node

## ============================================================================
## modules/pet/api.gd — Pet 模块的公共接口契约
## ============================================================================
## 【用途】
##   本文件定义 Pet 模块对外暴露的所有公共接口（信号、方法、属性）。
##   其他模块与 Pet 模块交互时，必须且只能通过此处定义的接口。
##   这是模块间通信的唯一合法通道，确保低耦合。

## 信号 ——— 宠物状态变更通知

signal pet_scale_changed(new_scale: float)
signal material_changed(preset_id: String)
signal settings_requested
signal exit_requested

## 公共方法 ——— 外部可调用的接口

func open_settings_window():
	push_error("[Pet API] open_settings_window() must be implemented by pet.gd")

func update_pet_scale(new_scale: float):
	push_error("[Pet API] update_pet_scale() must be implemented by pet.gd")

func get_current_material_name(slime_id: String = "slime_1") -> String:
	push_error("[Pet API] get_current_material_name() must be implemented by pet.gd")
	return ""

func on_material_changed(preset_id: String):
	push_error("[Pet API] on_material_changed() must be implemented by pet.gd")
