class_name TestMathUtils
extends GdUnitTestSuite


func test_average_vector2_empty() -> void:
	var result := MathUtils.average_vector2([])
	assert_that(result).is_equal(Vector2.ZERO)


func test_average_vector2_single() -> void:
	var arr: Array[Vector2] = [Vector2(5, 10)]
	var result := MathUtils.average_vector2(arr)
	assert_that(result).is_equal(Vector2(5, 10))


func test_average_vector2_multiple() -> void:
	var arr: Array[Vector2] = [Vector2(2, 4), Vector2(4, 6), Vector2(6, 8)]
	var result := MathUtils.average_vector2(arr)
	assert_that(result).is_equal(Vector2(4, 6))


func test_push_sliding_window_within_limit() -> void:
	var arr: Array = [1, 2, 3]
	MathUtils.push_sliding_window(arr, 4, 10)
	assert_int(arr.size()).is_equal(4)
	assert_int(arr[3]).is_equal(4)


func test_push_sliding_window_exceeds_limit() -> void:
	var arr: Array = [1, 2, 3]
	MathUtils.push_sliding_window(arr, 4, 3)
	assert_int(arr.size()).is_equal(3)
	assert_array(arr).contains(2, 3, 4)


func test_gaussian_kernel_default_sigma() -> void:
	var weights := MathUtils.gaussian_kernel(2.0)
	assert_int(weights.size()).is_equal(5)
	var total := 0.0
	for i in weights.size():
		total += weights[i]
	assert_float(total).is_between(0.9999, 1.0001)


func test_gaussian_kernel_custom_sigma() -> void:
	var weights := MathUtils.gaussian_kernel(1.0, 0.5)
	assert_int(weights.size()).is_equal(3)
	assert_float(weights[0]).is_greater(0.0)
	assert_float(weights[1]).is_greater(weights[0])
