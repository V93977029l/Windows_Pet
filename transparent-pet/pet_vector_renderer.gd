class_name PetVectorRenderer

const RENDER_SCALE: float = 4.0

var sprite: Sprite2D = null

func init(target_sprite: Sprite2D, svg_file_path: String):
	sprite = target_sprite
	var texture = load(svg_file_path)
	if texture and texture is Texture2D:
		sprite.texture = texture
		sprite.scale = Vector2(1.0 / RENDER_SCALE, 1.0 / RENDER_SCALE)
		print("🔹 [矢量渲染] 初始化完成，默认缩放: ", 1.0/RENDER_SCALE)
	else:
		print("❌ [矢量渲染] 加载失败")

func update_scale(new_scale: float):
	if sprite:
		var actual_scale = new_scale / RENDER_SCALE
		sprite.scale = Vector2(actual_scale, actual_scale)
		print("🔹 [矢量渲染] 显示缩放: ", new_scale, " -> 实际缩放: ", actual_scale)
