class_name LiquidGlassController
extends PetEffectsAPI

var parent_node: Node2D = null
var target_sprite: Sprite2D = null

var liquid_glass_renderer: Node2D = null
var glass_item: GlassItem = null

const LIQUID_GLASS_SCENE: String = "res://prototypes/liquid_glass/scenes/liquid_glass_renderer.tscn"


func init(p_node: Node2D, p_sprite: Sprite2D):
	parent_node = p_node
	target_sprite = p_sprite
	print("✅ [液态玻璃控制器] 初始化完成")


func has_active_effect() -> bool:
	return liquid_glass_renderer != null and glass_item != null


func get_active_effect_id() -> String:
	if has_active_effect():
		return "liquid_glass"
	return ""


func activate_effect(effect_id: String):
	match effect_id:
		"liquid_glass":
			_setup_liquid_glass()
		_:
			printerr("[液态玻璃控制器] 未知特效: ", effect_id)


func deactivate_effect(_effect_id: String):
	_teardown_liquid_glass()


func sync_position(global_pos: Vector2, dpr: float):
	if glass_item and liquid_glass_renderer:
		glass_item.position = global_pos * dpr
		liquid_glass_renderer.update_items_uniforms()


func _ensure_liquid_glass_renderer() -> bool:
	if liquid_glass_renderer:
		return true
	var scene = load(LIQUID_GLASS_SCENE)
	if not scene:
		printerr("[液态玻璃] 无法加载场景: ", LIQUID_GLASS_SCENE)
		return false
	liquid_glass_renderer = scene.instantiate()
	parent_node.add_child(liquid_glass_renderer)
	print("✅ [液态玻璃] 渲染器已动态创建")
	return true


func _teardown_liquid_glass():
	glass_item = null
	if liquid_glass_renderer:
		liquid_glass_renderer.queue_free()
		liquid_glass_renderer = null
		print("✅ [液态玻璃] 渲染器已移除")
	if target_sprite:
		target_sprite.modulate.a = 1.0
	effect_deactivated.emit("liquid_glass")


func _setup_liquid_glass():
	if not _ensure_liquid_glass_renderer():
		return
	if not target_sprite:
		return

	liquid_glass_renderer.bg_type = ConfigManager.cfg_get("liquid_glass", "glass_bg_type", 3)
	liquid_glass_renderer.blur_edge = ConfigManager.cfg_get("liquid_glass", "glass_blur_edge", true)
	liquid_glass_renderer.blur_radius = ConfigManager.cfg_get("liquid_glass", "glass_blur_radius", 2.0)

	var glass_color = Color(
		ConfigManager.cfg_get("liquid_glass", "glass_tint_r", 0.3),
		ConfigManager.cfg_get("liquid_glass", "glass_tint_g", 0.6),
		ConfigManager.cfg_get("liquid_glass", "glass_tint_b", 0.9),
		1.0
	)
	liquid_glass_renderer.tint = glass_color
	liquid_glass_renderer.tint_alpha = ConfigManager.cfg_get("liquid_glass", "glass_tint_alpha", 0.35)

	var item_manager = liquid_glass_renderer.get_item_manager()
	item_manager.clear_all()

	var dpr: float = parent_node.get_tree().root.content_scale_factor
	var pos = target_sprite.global_position * dpr

	var slime_item = GlassItem.new()
	slime_item.shape_type = GlassItem.ShapeType.SLIME
	slime_item.position = pos
	slime_item.width = ConfigManager.cfg_get("liquid_glass", "glass_item_width", 200.0)
	slime_item.height = ConfigManager.cfg_get("liquid_glass", "glass_item_height", 132.0)
	slime_item.radius = ConfigManager.cfg_get("liquid_glass", "glass_item_radius", 65.0)
	slime_item.scale = ConfigManager.cfg_get("pet", "pet_scale", 1.0)
	slime_item.enabled = true

	item_manager.add_item(slime_item)

	glass_item = slime_item

	liquid_glass_renderer.update_items_uniforms()
	liquid_glass_renderer.update_all_uniforms()

	print("✅ [液态玻璃] 已创建，跟史莱姆位置同步")
	if target_sprite:
		target_sprite.modulate.a = 0.0

	effect_activated.emit("liquid_glass")
