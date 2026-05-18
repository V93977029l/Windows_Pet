class_name PetMouseManager

var passthrough_manager = null
var pet_node: Node2D = null
var parent_node: Node2D = null
var last_is_over_sprite = false

func init(p_node: Node2D, p_pet_node: Node2D, p_passthrough_manager):
	parent_node = p_node
	pet_node = p_pet_node
	passthrough_manager = p_passthrough_manager

func is_mouse_over_sprite() -> bool:
	if not pet_node:
		return false
	
	var mouse_pos = parent_node.get_global_mouse_position()
	
	if pet_node is Sprite2D:
		var sprite = pet_node as Sprite2D
		if not sprite.texture:
			return false
		
		var sprite_rect = sprite.get_rect()
		var sprite_global_rect = Rect2(sprite.global_position - sprite_rect.size / 2, sprite_rect.size)
		
		if not sprite_global_rect.has_point(mouse_pos):
			return false
		
		var local_pos = sprite.to_local(mouse_pos)
		var texture_size = sprite.texture.get_size()
		var pixel_pos = Vector2(
			int((local_pos.x + sprite_rect.size.x / 2) / sprite_rect.size.x * texture_size.x),
			int((local_pos.y + sprite_rect.size.y / 2) / sprite_rect.size.y * texture_size.y)
		)
		
		if pixel_pos.x < 0 or pixel_pos.x >= texture_size.x or pixel_pos.y < 0 or pixel_pos.y >= texture_size.y:
			return false
		
		var image = sprite.texture.get_image()
		if not image:
			return false
		
		var color = image.get_pixel(pixel_pos.x, pixel_pos.y)
		return color.a > 0
		
	elif pet_node is Polygon2D:
		var polygon = pet_node as Polygon2D
		var local_pos = polygon.to_local(mouse_pos)
		
		var min_x = INF
		var max_x = -INF
		var min_y = INF
		var max_y = -INF
		
		for point in polygon.polygon:
			min_x = min(min_x, point.x)
			max_x = max(max_x, point.x)
			min_y = min(min_y, point.y)
			max_y = max(max_y, point.y)
		
		var poly_rect = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
		return poly_rect.has_point(local_pos)
	
	return false

func update_mouse_passthrough():
	if passthrough_manager:
		var is_over_sprite = is_mouse_over_sprite()
		
		if is_over_sprite != last_is_over_sprite:
			if is_over_sprite:
				print("📋 [桌宠鼠标] 鼠标进入 - 禁用穿透")
			else:
				print("📋 [桌宠鼠标] 鼠标离开 - 启用穿透")
			last_is_over_sprite = is_over_sprite
			
			passthrough_manager.update_mouse_passthrough(is_over_sprite)