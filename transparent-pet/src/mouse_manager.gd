## MouseManager - 鼠标交互管理器
## =========================================================================
## 【架构定位】
##   本类是桌宠鼠标交互系统的核心控制器，负责管理鼠标与精灵之间的
##   碰撞检测（像素级精确检测），以及窗口鼠标穿透模式（Click-through）
##   的自动切换逻辑。
##
## 【设计模式】
##   采用"门面模式"封装了底层复杂的像素级碰撞检测代码，向上层
##   （main.gd）暴露简洁的API接口。同时采用了"观察者模式"——通过
##   last_is_over_sprite 状态缓存避免重复的穿透模式切换。
##
## 【核心职责】
##   1. 像素级精确检测：判断鼠标是否悬停在任一史莱姆精灵的非透明像素上
##      - 对 Sprite2D：通过 get_pixel() 读取纹理alpha通道
##      - 对 Polygon2D：通过多边形包围盒判断
##   2. 穿透模式切换：鼠标在史莱姆上时禁用穿透（可点击/拖拽），
##      鼠标离开时启用穿透（点击穿透到桌面/下层窗口）
##   3. 状态缓存：通过 last_is_over_sprite 避免无效的模式切换调用
##
## 【命名约定】
##   - slime_1_node: 1号史莱姆精灵节点（主控史莱姆，可拖拽）
##   - slime_2_node: 2号史莱姆精灵节点（装饰性/辅助史莱姆）
## =========================================================================

class_name MouseManager

## 窗口穿透管理器引用（来自Godot插件）
## 用于控制窗口的鼠标穿透行为：穿透打开时，鼠标事件会透过窗口到达桌面
var passthrough_manager = null

## 1号史莱姆的节点引用（Node2D）
## 主控史莱姆——可被拖拽、可被点击交互的主要精灵
var slime_1_node: Node2D = null

## 2号史莱姆的节点引用（Node2D）
## 辅助史莱姆——用于装饰或辅助显示，可以有独立的交互行为
var slime_2_node: Node2D = null

## 父节点引用，用于获取全局鼠标位置等
var parent_node: Node2D = null

## 鼠标穿透状态的缓存标志
## 用于避免每帧都调用穿透管理器进行切换，仅在状态实际变化时才触发
## true: 上一帧鼠标在某史莱姆精灵之上（穿透已禁用）
## false: 上一帧鼠标不在任何史莱姆精灵之上（穿透已启用）
var last_is_over_sprite = false


## 初始化鼠标管理器
## 【参数】
##   p_node: Node2D - 父节点引用，通常传入场景根节点
##   p_slime_1_node: Node2D - 1号史莱姆节点（主角史莱姆）
##   p_passthrough_manager - 窗口穿透管理器实例（来自扩展插件）
## 【核心逻辑】
##   保存所有必要的引用，供后续检测方法使用
func init(p_node: Node2D, p_slime_1_node: Node2D, p_passthrough_manager):
	parent_node = p_node
	slime_1_node = p_slime_1_node
	passthrough_manager = p_passthrough_manager


## 设置2号史莱姆精灵的引用
## 【参数】
##   p_slime_2_sprite: Sprite2D - 2号史莱姆的精灵节点
## 【用途】
##   2号史莱姆是辅助/装饰性的精灵。设置后，鼠标悬停检测也会
##   包含该精灵，即鼠标在任一史莱姆上都会禁用穿透模式。
## 【边界情况】
##   如果从未调用此方法，slime_2_node 保持为 null，
##   is_mouse_over_any() 在检测时会自动跳过 null 节点。
func set_slime_2_sprite(p_slime_2_sprite: Sprite2D):
	slime_2_node = p_slime_2_sprite


## 判断鼠标是否在指定节点之上（像素级精确检测）
## 【参数】
##   node: Node2D - 要检测的节点（支持Sprite2D和Polygon2D）
## 【返回值】
##   bool - true: 鼠标在该节点的可见像素上；false: 不在或节点无效
## 【检测流程】
##   ———— Sprite2D 检测流程 ————
##   1. 获取全局鼠标坐标
##   2. 获取精灵的全局矩形包围盒（以精灵中心为中心、texture尺寸为大小）
##   3. 先用包围盒做快速剔除（性能优化，避免不必要的像素级检测）
##   4. 将鼠标坐标转换到精灵的本地坐标
##   5. 计算鼠标对应的像素坐标（考虑scale缩放）
##   6. 通过 get_pixel() 读取该像素的alpha值
##   7. alpha > 0 → 鼠标在可见像素上
##
##   ———— Polygon2D 检测流程 ————
##   1. 获取全局鼠标坐标
##   2. 将鼠标坐标转换到多边形的本地坐标
##   3. 计算多边形的轴对齐包围盒
##   4. 判断鼠标本地坐标是否在包围盒内
##
## 【为什么需要像素级检测？】
##   简单的包围盒检测会导致在精灵的透明区域（如SVG的空白区域）
##   也被视为"在精灵上"，造成误触发。像素级检测只响应可见像素，
##   用户体验更精确。
## 【性能说明】
##   先用包围盒做快速剔除，避免每帧都调用 get_pixel()（纹理读取）。
##   只有包围盒命中时才会进入像素级检测，性能开销可控。
func _is_mouse_over_node(node: Node2D) -> bool:
	if not node:
		return false
	
	var mouse_pos = parent_node.get_global_mouse_position()
	
	if node is Sprite2D:
		var sprite = node as Sprite2D
		if not sprite.texture:
			return false
		
		# 计算精灵的全局包围矩形（以精灵中心为锚点）
		var sprite_rect = sprite.get_rect()
		var sprite_global_rect = Rect2(sprite.global_position - sprite_rect.size / 2, sprite_rect.size)
		
		# 快速剔除：鼠标不在包围盒内则直接返回false
		if not sprite_global_rect.has_point(mouse_pos):
			return false
		
		# 像素级检测：将鼠标坐标转换为纹理像素坐标，读取alpha值
		var local_pos = sprite.to_local(mouse_pos)
		var texture_size = sprite.texture.get_size() * sprite.scale
		var pixel_pos = Vector2i(int(local_pos.x + texture_size.x / 2), int(local_pos.y + texture_size.y / 2))
		
		# 像素坐标越界检查
		if pixel_pos.x < 0 or pixel_pos.x >= texture_size.x or pixel_pos.y < 0 or pixel_pos.y >= texture_size.y:
			return false
		
		var image = sprite.texture.get_image()
		if not image:
			return false
		
		# 读取像素alpha值：alpha > 0 表示该像素可见
		var color = image.get_pixel(pixel_pos.x, pixel_pos.y)
		return color.a > 0
		
	elif node is Polygon2D:
		var polygon = node as Polygon2D
		var local_pos = polygon.to_local(mouse_pos)
		
		# 计算多边形的轴对齐包围盒（AABB）
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


## 判断鼠标是否在任一史莱姆节点之上
## 【返回值】
##   bool - true: 鼠标在1号或2号史莱姆的可见像素上
## 【核心逻辑】
##   分别检测 slime_1_node 和 slime_2_node，使用逻辑或连接。
##   如果某个节点为 null，_is_mouse_over_node() 会安全返回 false。
func is_mouse_over_any() -> bool:
	return _is_mouse_over_node(slime_1_node) or _is_mouse_over_node(slime_2_node)


## 更新鼠标穿透模式
## 【核心逻辑】
##   每帧由主循环调用此方法。
##   1. 检测鼠标是否在任一史莱姆上
##   2. 与上一帧的状态（last_is_over_sprite）比较
##   3. 仅在状态发生变化时才调用穿透管理器进行切换
##      - 鼠标进入 → 禁用穿透（让鼠标事件能到达史莱姆，用于拖拽和交互）
##      - 鼠标离开 → 启用穿透（让鼠标事件透过窗口到达桌面）
## 【为什么需要状态缓存？】
##   频繁调用穿透管理器的切换API可能带来不必要的系统开销。
##   last_is_over_sprite 确保只在状态真正改变时才执行切换操作，
##   大幅减少API调用次数。
## 【穿透模式原理】
##   启用穿透后，窗口对鼠标"透明"——鼠标点击会穿过窗口到达桌面。
##   这允许用户与桌宠下方的桌面图标或窗口交互。禁用穿透后，
##   鼠标事件由当前窗口捕获，用户可以拖拽史莱姆或点击UI元素。
func update_mouse_passthrough():
	if passthrough_manager:
		var is_over = is_mouse_over_any()
		
		if is_over != last_is_over_sprite:
			if is_over:
				print("📋 [桌宠鼠标] 鼠标进入 - 禁用穿透")
			else:
				print("📋 [桌宠鼠标] 鼠标离开 - 启用穿透")
			last_is_over_sprite = is_over
			
			passthrough_manager.update_mouse_passthrough(is_over)
