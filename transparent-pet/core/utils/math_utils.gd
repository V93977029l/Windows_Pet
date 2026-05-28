class_name MathUtils

## 计算 Vector2 数组的算术平均值（空数组返回零向量）
static func average_vector2(arr: Array[Vector2]) -> Vector2:
	if arr.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for v in arr:
		sum += v
	return sum / float(arr.size())

## 滑动窗口追加：先追加值，再弹出超出 max_size 的旧元素（FIFO 队列）
static func push_sliding_window(arr: Array, value: Variant, max_size: int) -> void:
	arr.append(value)
	while arr.size() > max_size:
		arr.pop_front()

## 逐分量计算 Vector2 的符号（x 和 y 各自取 sign）
static func sign_vector2(v: Vector2) -> Vector2:
	return Vector2(sign(v.x), sign(v.y))

## 计算一维归一化高斯模糊核权重
## @param radius: 核半径（最终核宽度 = 2*radius + 1）
## @param sigma: 标准差，默认 -1 表示自动使用 radius/3
static func gaussian_kernel(radius: float, sigma: float = -1.0) -> PackedFloat32Array:
	var s: float = sigma if sigma > 0 else radius / 3.0
	var weights := PackedFloat32Array()
	var total := 0.0
	for i in range(int(radius * 2) + 1):
		var x := float(i) - radius
		var w := exp(-x * x / (2.0 * s * s))
		weights.append(w)
		total += w
	for i in range(weights.size()):
		weights[i] /= total
	return weights
