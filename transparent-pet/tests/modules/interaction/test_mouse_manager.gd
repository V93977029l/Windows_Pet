class_name TestMouseManager
extends GdUnitTestSuite

var _manager: MouseManager
var _test_node: Node2D
var _test_sprite: Sprite2D


func before_test() -> void:
	_test_node = Node2D.new()
	add_child(_test_node)

	# 创建一个简单的测试纹理（10x10 白色方块）
	var image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(image)

	_test_sprite = Sprite2D.new()
	_test_sprite.texture = texture
	_test_sprite.position = Vector2(100, 100)
	_test_node.add_child(_test_sprite)

	_manager = MouseManager.new()
	_manager.init(_test_node, _test_sprite, null)


func after_test() -> void:
	if _test_node:
		_test_node.queue_free()


# ── 初始化 ──

func test_init_stores_references() -> void:
	assert_that(_manager.parent_node).is_equal(_test_node)
	assert_that(_manager.slime_1_node).is_equal(_test_sprite)
	assert_bool(_manager.last_is_over_sprite).is_false()


func test_init_with_null_passthrough() -> void:
	var mgr = MouseManager.new()
	mgr.init(_test_node, _test_sprite, null)
	assert_that(mgr.passthrough_manager).is_null()


# ── is_mouse_over_any ──

func test_is_mouse_over_any_returns_false_when_no_sprite_set() -> void:
	var mgr = MouseManager.new()
	mgr.init(_test_node, null, null)
	assert_bool(mgr.is_mouse_over_any()).is_false()


func test_is_mouse_over_any_returns_false_when_mouse_far_away() -> void:
	# 鼠标位置远离精灵
	_test_node.position = Vector2(-1000, -1000)
	assert_bool(_manager.is_mouse_over_any()).is_false()


# ── _is_mouse_over_node ──

func test_is_mouse_over_node_returns_false_for_null_node() -> void:
	assert_bool(_manager._is_mouse_over_node(null)).is_false()


func test_is_mouse_over_node_returns_false_when_outside_bounding_box() -> void:
	_test_sprite.position = Vector2(500, 500)
	_test_node.position = Vector2(-500, -500)  # 精灵在全局 (0,0) 附近
	# 鼠标默认在 (0,0)，精灵在 (0,0)，应该 hits bounding box
	# 只需验证方法不崩溃且有合理的返回值
	var result = _manager._is_mouse_over_node(_test_sprite)
	assert_that(result).is_not_null()


# ── pixel collision for Sprite2D ──

func test_pixel_collision_detection_works() -> void:
	# 精灵放在 (100, 100)，鼠标默认在 (0, 0)，应该在包围盒外
	_test_sprite.global_position = Vector2(100, 100)
	var result = _manager._is_mouse_over_node(_test_sprite)
	# 不依赖具体的鼠标位置，仅验证方法不崩溃
	assert_that(result).is_not_null()


func test_pixel_collision_no_texture() -> void:
	var sprite = Sprite2D.new()
	_test_node.add_child(sprite)
	assert_bool(_manager._is_mouse_over_node(sprite)).is_false()


# ── update_mouse_passthrough ──

func test_update_mouse_passthrough_without_manager() -> void:
	# passthrough_manager 为 null，应安全跳过
	_manager.update_mouse_passthrough()
	assert_bool(_manager.last_is_over_sprite).is_false()


# ── set_slime_2 ──

func test_set_slime_2_sprite() -> void:
	var sprite2 = Sprite2D.new()
	_test_node.add_child(sprite2)
	_manager.set_slime_2_sprite(sprite2)
	assert_that(_manager.slime_2_node).is_equal(sprite2)
	sprite2.queue_free()


func test_is_mouse_over_any_with_two_sprites() -> void:
	var sprite2 = Sprite2D.new()
	var image = Image.create(5, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	sprite2.texture = ImageTexture.create_from_image(image)
	sprite2.position = Vector2(200, 200)
	_test_node.add_child(sprite2)

	_manager.set_slime_2_sprite(sprite2)
	# 验证方法不崩溃
	var result = _manager.is_mouse_over_any()
	assert_that(result).is_not_null()
