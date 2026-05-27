## VectorRenderer - SVG矢量渲染器
## =========================================================================
## 【架构定位】
##   本类负责桌宠精灵的SVG矢量渲染功能，实现从矢量图形（SVG格式）
##   到光栅纹理（Texture2D）的运行时转换。这使得桌宠在不同缩放级别下
##   都能保持清晰锐利的显示效果，避免了传统位图放大的模糊问题。
##
## 【设计模式】
##   采用"代理模式"——将渲染逻辑从主节点中抽离，委托给本类处理。
##   主节点只需调用 init() 和 update_scale() / apply_high_res_scale()，
##   无需关心底层SVG解析和纹理创建的细节。
##
## 【核心职责】
##   1. SVG文件加载与内容读取（用于后续运行时渲染）
##   2. 精灵缩放更新（简单scale调整，保持纹理不变）
##   3. 高清重渲染（根据新缩放值重新从SVG生成纹理，适合大幅度缩放）
##
## 【两级缩放策略】
##   - 普通缩放（update_scale）: 直接修改精灵的 scale 属性，快速但低倍率下
##     可能会有像素化（因为纹理分辨率固定）
##   - 高清缩放（apply_high_res_scale）: 从原始SVG重新栅格化，生成与目标
##     尺寸匹配的高分辨率纹理，然后重置scale为1.0。此方法更慢但画质更好
##
## 【常量定义】
##   BASE_SIZE = (200, 132): 原始纹理的基础尺寸，用于高清渲染时的基数计算
## =========================================================================

class_name VectorRenderer
const BASE_SIZE: Vector2 = Vector2(200, 132)

## 目标精灵节点引用——纹理将被设置到这个精灵上
var sprite: Sprite2D = null

## SVG文件的路径（如 "res://assets/sprites/slime.svg"）
## 用于初始加载纹理和后续的高清重渲染
var svg_path: String = ""

## SVG文件的原始文本内容（字符串形式）
## 运行时保存在内存中，用于 apply_high_res_scale() 中的重渲染
## 注意：这是原始SVG XML文本，不是解析后的对象
var svg_content: String = ""


## 初始化矢量渲染器
## 【参数】
##   target_sprite: Sprite2D - 目标精灵节点，纹理将应用到该节点
##   svg_file_path: String - SVG文件的项目路径（如 "res://assets/xxx.svg"）
## 【核心逻辑】
##   1. 保存精灵引用和SVG路径
##   2. 将SVG原始内容加载到内存（svg_content）
##   3. 尝试直接加载SVG为纹理（Godot支持SVG→Texture2D的自动转换）
##   4. 如果加载成功，设置精灵纹理并重置缩放
## 【为什么同时保存路径和内容？】
##   - svg_path: 用于 load() 快速加载纹理（Godot内置的SVG→纹理转换）
##   - svg_content: 用于 apply_high_res_scale() 中的自定义尺寸渲染
##   Godot的 load() 使用默认分辨率渲染SVG，而 image.load_svg_from_string()
##   可以指定渲染分辨率，实现真正的高清缩放。
func init(target_sprite: Sprite2D, svg_file_path: String):
	sprite = target_sprite
	svg_path = svg_file_path
	
	load_svg_content()
	
	var texture = load(svg_path)
	if texture and texture is Texture2D:
		sprite.texture = texture
		sprite.scale = Vector2(1.0, 1.0)


## 加载SVG文件的原始文本内容到内存
## 【核心逻辑】
##   使用 FileAccess 以只读模式打开SVG文件，读取全部文本到 svg_content。
##   这允许后续的 apply_high_res_scale() 在不重新读取文件的情况下，
##   直接用 image.load_svg_from_string() 以任意分辨率渲染。
## 【边界情况】
##   - 文件不存在 → svg_content 保持为空字符串，后续的高清渲染会失败并报错
##   - 文件可读但内容为空 → svg_content 为空字符串，同样无法渲染
func load_svg_content():
	var file = FileAccess.open(svg_path, FileAccess.READ)
	if file:
		svg_content = file.get_as_text()
		file.close()
		print("✅ [矢量渲染] SVG内容加载成功")
	else:
		print("⚠️ [矢量渲染] 无法读取原始SVG，仅供编辑器模式使用")


## 更新精灵缩放（简单缩放，不重新渲染纹理）
## 【参数】
##   new_scale: float - 新的缩放倍率（如 1.5 表示150%）
## 【核心逻辑】
##   直接修改精灵的 scale 属性为 (new_scale, new_scale)。
##   这是"快速缩放"——纹理本身不变，只是精灵在屏幕上的显示尺寸改变。
## 【适用场景】
##   小幅度的缩放调整（如 0.8 ~ 1.5 倍），对于大幅缩放请使用
##   apply_high_res_scale() 以获得更好的画质。
## 【局限】
##   当 new_scale > 1.0 时，纹理会因放大而出现模糊/像素化；
##   当 new_scale < 0.5 时，纹理会因缩小而丢失细节。
func update_scale(new_scale: float):
	if sprite:
		sprite.scale = Vector2(new_scale, new_scale)


## 高清缩放——从SVG重新渲染纹理（高质量但更耗性能）
## 【参数】
##   new_scale: float - 目标缩放倍率（如 2.0 表示200%）
## 【核心逻辑】
##   1. 保护性检查：缩放倍率不能小于0.1（防止极端缩小导致的空纹理）
##   2. 检查精灵和SVG内容是否有效
##   3. 创建空 Image 对象
##   4. 调用 image.load_svg_from_string() 从SVG文本渲染位图
##      - 渲染倍率 = new_scale * 2（乘以2是为了额外的像素密度保障）
##   5. 如果渲染成功，将Image转为ImageTexture并设置到精灵
##   6. 重置精灵的 scale 为 (1.0, 1.0)（因为纹理本身已经是目标分辨率了）
## 【为什么 scale * 2？】
##   乘以2提供了额外的像素密度（类似Retina显示的2x分辨率），
##   在高DPI显示器上显示更清晰，同时也防止了边缘锯齿。
## 【性能说明】
##   此方法的 SVG 解析和光栅化操作有一定性能开销，不适合每帧调用。
##   适合在用户完成缩放操作后调用（如滑块释放时）。
## 【边界情况】
##   - new_scale < 0.1 → 自动修正为 0.1
##   - sprite 为 null 或 svg_content 为空 → 打印错误并返回
##   - load_svg_from_string() 失败 → 打印错误码并返回
func apply_high_res_scale(new_scale: float):
	if new_scale < 0.1:
		new_scale = 0.1

	if not sprite or svg_content.is_empty():
		print("❌ [矢量渲染] 无法渲染：精灵或SVG内容为空")
		return
	
	var image = Image.new()
	var result = image.load_svg_from_string(svg_content, new_scale * 2)
	
	if result == OK:
		var new_texture = ImageTexture.create_from_image(image)
		sprite.texture = new_texture
		sprite.scale = Vector2(1.0, 1.0)
		print("✅ [矢量渲染] SVG高清渲染完成")
	else:
		print("❌ [矢量渲染] SVG渲染失败，错误码: ", result)
