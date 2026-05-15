class_name PetVectorRenderer
const BASE_SIZE: Vector2 = Vector2(200, 132)

var sprite: Sprite2D = null
var svg_path: String = ""
var svg_content: String = ""

func init(target_sprite: Sprite2D, svg_file_path: String):
	sprite = target_sprite
	svg_path = svg_file_path
	
	load_svg_content()
	
	var texture = load(svg_path)
	if texture and texture is Texture2D:
		sprite.texture = texture
		sprite.scale = Vector2(1.0, 1.0)

func load_svg_content():
	var file = FileAccess.open(svg_path, FileAccess.READ)
	if file:
		svg_content = file.get_as_text()
		file.close()
		print("✅ [矢量渲染] SVG内容加载成功")
	else:
		print("❌ [矢量渲染] 无法读取SVG文件: ", svg_path)

func update_scale(new_scale: float):
	if sprite:
		sprite.scale = Vector2(new_scale, new_scale)

func apply_high_res_scale(new_scale: float):
	# 防止缩放为 0，避免崩溃
	if new_scale < 0.1:
		new_scale = 0.1

	if not sprite or svg_content.is_empty():
		print("❌ [矢量渲染] 无法渲染：精灵或SVG内容为空")
		return
	
	# 关键：Godot 4 正确 SVG 渲染方式（只传缩放值，不传尺寸）
	var image = Image.new()
	var result = image.load_svg_from_string(svg_content, new_scale * 2)
	
	if result == OK:
		var new_texture = ImageTexture.create_from_image(image)
		sprite.texture = new_texture
		sprite.scale = Vector2(1.0, 1.0) # 高清纹理不需要再缩放
		print("✅ [矢量渲染] SVG高清渲染完成")
	else:
		print("❌ [矢量渲染] SVG渲染失败，错误码: ", result)
