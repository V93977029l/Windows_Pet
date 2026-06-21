class_name CharacterAPI
extends Node

## ============================================================================
## modules/character/api.gd — 多宠物角色框架的公共接口契约
## ============================================================================
## 【架构定位】
##   本类定义"角色注册表"与"角色数据载体"的对外契约。
##   任何角色（史莱姆、猫咪、机器人...）都以 CharacterData 形式
##   注册到注册表中，其他模块通过 CharacterAPI 查询角色信息。
##
## 【为什么独立成模块？】
##   - 角色与材质（Material）是两个维度：同一个角色可以有
##     不同材质皮肤；不同角色可以共享同一套着色器。
##   - 角色涉及 SVG 资源、物理参数、默认行为等差异化数据，
##     需要独立的注册表管理。
##
## 【占位说明】
##   当前仅实现框架：注册 → 查询 → 切换。具体角色数据
##   （精灵路径、默认材质、默认物理参数）仍使用原始配置，
##   仅提供"可以切换角色"的接口。
## ============================================================================

## 角色切换时触发（新角色 id）
signal character_changed(character_id: String)

var _registry = null

func register_character(character_data: Dictionary) -> void:
	push_error("[CharacterAPI] register_character() must be implemented")

func get_character(character_id: String) -> Dictionary:
	push_error("[CharacterAPI] get_character() must be implemented")
	return {}

func get_all_character_ids() -> Array:
	push_error("[CharacterAPI] get_all_character_ids() must be implemented")
	return []

func get_current_character_id() -> String:
	push_error("[CharacterAPI] get_current_character_id() must be implemented")
	return ""

func switch_character(character_id: String) -> void:
	push_error("[CharacterAPI] switch_character() must be implemented")
