# 桌宠鼠标管理器
# 功能：处理鼠标是否在精灵范围内的判断逻辑

class_name PetMouseManager

var passthrough_manager = null
var pet_sprite: Sprite2D = null
var parent_node: Node2D = null
var last_is_over_sprite = false  # 跟踪上一帧的鼠标状态

# 初始化函数
func init(p_node: Node2D, p_sprite: Sprite2D, p_passthrough_manager):
	parent_node = p_node
	pet_sprite = p_sprite
	passthrough_manager = p_passthrough_manager

# 检查鼠标是否在精灵上
func is_mouse_over_sprite() -> bool:
	if not pet_sprite:
		return false
	
	# 获取鼠标位置
	var mouse_pos = parent_node.get_global_mouse_position()
	
	# 检查鼠标是否在精灵的边界框内
	var sprite_rect = pet_sprite.get_rect()
	var sprite_global_rect = Rect2(pet_sprite.global_position - sprite_rect.size / 2, sprite_rect.size)
	
	return sprite_global_rect.has_point(mouse_pos)

# 更新鼠标穿透状态
func update_mouse_passthrough():
	if passthrough_manager:
		var is_over_sprite = is_mouse_over_sprite()
		
		# 检查鼠标状态是否变化
		if is_over_sprite != last_is_over_sprite:
			if is_over_sprite:
				print("📋 [桌宠鼠标] 鼠标进入精灵范围，禁用穿透")
			else:
				print("📋 [桌宠鼠标] 鼠标离开精灵范围，启用穿透")
			last_is_over_sprite = is_over_sprite
			
			# 只在鼠标状态变化时更新鼠标穿透状态
			passthrough_manager.update_mouse_passthrough(is_over_sprite)
