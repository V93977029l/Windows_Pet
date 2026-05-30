class_name TestDragController
extends GdUnitTestSuite

const PetConsts = preload("res://modules/pet/scripts/pet_constants.gd")

var _controller: DragController


func before_test() -> void:
	_controller = DragController.new()


func after_test() -> void:
	pass


func test_init_sets_default_values() -> void:
	assert_bool(_controller.is_dragging).is_false()
	assert_bool(_controller.is_throwing).is_false()
	assert_that(_controller.throw_velocity).is_equal(Vector2.ZERO)


func test_throw_disabled_prevents_throw() -> void:
	_controller.update_throw_params(800.0, 100.0, 500.0, 2.0, false)
	assert_bool(_controller.throw_enabled).is_false()


func test_throw_enabled_by_default() -> void:
	assert_bool(_controller.throw_enabled).is_true()


func test_update_throw_params() -> void:
	_controller.update_throw_params(600.0, 200.0, 700.0, 3.0, true)
	assert_float(_controller.throw_gravity).is_equal(600.0)
	assert_float(_controller.throw_min_speed).is_equal(200.0)
	assert_float(_controller.throw_max_speed).is_equal(700.0)
	assert_float(_controller.throw_multiplier).is_equal(3.0)
	assert_bool(_controller.throw_enabled).is_true()


func test_update_physics_params() -> void:
	_controller.update_physics_params(0.5, 0.8, 600.0, 400.0)
	assert_float(_controller.ground_bounce).is_equal(0.5)
	assert_float(_controller.wall_bounce).is_equal(0.8)
	assert_float(_controller.ground_friction).is_equal(600.0)
	assert_float(_controller.fall_threshold).is_equal(400.0)


func test_update_svg_params() -> void:
	_controller.update_svg_params(0.5, 0.3, 100, 80)
	assert_float(_controller.svg_half_w_ratio).is_equal(0.5)
	assert_float(_controller.svg_bottom_offset_ratio).is_equal(0.3)
	assert_float(_controller.svg_fallback.x).is_equal(100.0)
	assert_float(_controller.svg_fallback.y).is_equal(80.0)


func test_velocity_buffer_limit() -> void:
	var max_size: int = PetConsts.VELOCITY_BUFFER_SIZE_DEFAULT
	for i in range(max_size + 5):
		MathUtils.push_sliding_window(_controller.velocity_buffer, Vector2(i, 0), max_size)
	assert_int(_controller.velocity_buffer.size()).is_equal(max_size)
	assert_that(_controller.velocity_buffer[0].x).is_equal(5.0)
