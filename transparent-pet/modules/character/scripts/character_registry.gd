class_name CharacterRegistry

## ============================================================================
## modules/character/scripts/character_registry.gd — 多宠物角色注册表
## ============================================================================
## 【架构定位】
##   多宠物角色的注册 / 查询 / 切换服务。
##   本类不继承 Node（隐式继承 RefCounted），由 pet.gd 持有实例。
##
## 【CharacterData 字段约定】
##   {
##     "id":          String,  # 唯一标识符（如 "slime"）
##     "name":        String,  # 显示名（UI 展示用）
##     "sprite":      String,  # SVG / 图像资源路径（res://...）
##     "material":    String,  # 默认材质预设 id，传空则用 slime_1
##     "scale":       float,   # 默认缩放，传 0 则用 PET_SCALE_DEFAULT
##     "description": String   # 简介
##   }
## ============================================================================

signal character_changed(character_id: String)

## 角色注册表：id -> Dictionary
var _characters: Dictionary = {}

## 当前激活的角色 id
var _current_id: String = "slime"


## ============================================================================
## 生命周期
## ============================================================================

func _init() -> void:
	_register_default_characters()


func _ready() -> void:
	pass


## 注册所有内置角色
func _register_default_characters() -> void:
	var slime := {
		"id": "slime",
		"name": "史莱姆",
		"sprite": "res://modules/pet/assets/pet_sprite.svg",
		"material": "slime_1",
		"scale": 1.0,
		"description": "蓝色的小史莱姆，会在你的桌面蹦蹦跳跳。"
	}
	_characters[slime.id] = slime

	# TODO(character): 在此追加更多角色注册。
	# 只需准备对应的 SVG 资源并在 modules/pet/assets/ 下放置，
	# 再把对应 CharacterData Dictionary 注册进来即可。

	print("[CharacterRegistry] 已注册 %d 个角色" % _characters.size())


## ============================================================================
## 公共 API
## ============================================================================

func register_character(character_data: Dictionary) -> void:
	if not character_data.has("id"):
		push_error("[CharacterRegistry] 注册角色缺少 'id' 字段")
		return
	var cid: String = character_data["id"]
	_characters[cid] = character_data
	print("[CharacterRegistry] 注册角色：", character_data.get("name", cid))


func get_character(character_id: String) -> Dictionary:
	if _characters.has(character_id):
		return _characters[character_id]
	push_error("[CharacterRegistry] 未找到角色 id: " + character_id)
	return {}


func get_all_character_ids() -> Array:
	return _characters.keys()


func get_current_character_id() -> String:
	return _current_id


## 切换到指定角色；触发 character_changed 信号。
func switch_character(character_id: String) -> void:
	if not _characters.has(character_id):
		push_error("[CharacterRegistry] 无法切换到未知角色: " + character_id)
		return
	_current_id = character_id
	character_changed.emit(character_id)
	print("[CharacterRegistry] 已切换到角色：", character_id)
