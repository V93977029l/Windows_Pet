class_name TestPetConstants
extends GdUnitTestSuite

const PetConsts = preload("res://modules/pet/scripts/pet_constants.gd")


func test_throw_gravity_default() -> void:
	assert_float(PetConsts.THROW_GRAVITY_DEFAULT).is_greater(0.0)
	assert_float(PetConsts.THROW_GRAVITY_DEFAULT).is_equal(800.0)


func test_throw_min_speed_default() -> void:
	assert_float(PetConsts.THROW_MIN_SPEED_DEFAULT).is_greater(0.0)


func test_throw_max_speed_default() -> void:
	assert_float(PetConsts.THROW_MAX_SPEED_DEFAULT).is_greater(PetConsts.THROW_MIN_SPEED_DEFAULT)


func test_bounce_coefficients_valid() -> void:
	assert_float(PetConsts.PHYSICS_GROUND_BOUNCE_DEFAULT).is_between(0.0, 1.0)
	assert_float(PetConsts.PHYSICS_WALL_BOUNCE_DEFAULT).is_between(0.0, 1.0)


func test_velocity_buffer_size_positive() -> void:
	assert_int(PetConsts.VELOCITY_BUFFER_SIZE_DEFAULT).is_greater(0)


func test_all_constants_non_zero() -> void:
	assert_float(PetConsts.SVG_HALF_W_RATIO_DEFAULT).is_greater(0.0)
	assert_float(PetConsts.SVG_BOTTOM_OFFSET_RATIO_DEFAULT).is_greater(0.0)
	assert_int(PetConsts.SVG_FALLBACK_SIZE_X_DEFAULT).is_greater(0)
	assert_int(PetConsts.SVG_FALLBACK_SIZE_Y_DEFAULT).is_greater(0)
