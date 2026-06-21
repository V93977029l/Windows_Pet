## MaterialManager - 材质管理系统
## =========================================================================
## 【架构定位】
##   本类是桌宠材质系统的核心管理器，实现了完整的"预设（Preset）"
##   材质注册与切换机制。它不继承Node，而是继承RefCounted作为
##   纯逻辑管理器，由主节点持有并调用。
##
## 【设计模式】
##   - 注册表模式（Registry Pattern）: MaterialRegistry 维护所有预设的字典映射
##   - 策略模式: 不同的材质预设通过不同的Shader实现不同的视觉效果
##   - 数据传输对象（DTO）: MaterialPreset 是纯数据载体类
##
## 【核心职责】
##   1. 材质预设的注册与管理：内置默认预设 + 支持扩展自定义预设
##   2. 材质切换：将指定预设的Shader应用到目标精灵上
##   3. 动态效果开关：控制Shader中的 enable_dynamic 参数
##
## 【内部类结构】
##   MaterialPreset  — 材质预设的数据载体（id、name、description、parameters）
##   MaterialRegistry — 预设注册表（增删查预设）
##
## 【使用方式】
##   var manager = MaterialManager.new()
##   manager.init(sprite)  # 传入目标精灵
##   var preset = manager.get_preset_by_id("slime_1")
##   manager.apply_preset(preset)
##   manager.set_dynamic_enabled(true)
## =========================================================================

class_name MaterialManager
extends RefCounted

## =========================================================================
## MaterialPreset — 材质预设数据类（内部类）
## =========================================================================
## 【用途】
##   封装单个材质预设的所有数据：唯一标识符、显示名称、描述文本、
##   以及可扩展的Shader参数字典。
## 【为什么作为内部类？】
##   材质预设的生命周期由MaterialManager管理，不对外独立使用。
##   作为内部类可以保持代码的内聚性，同时避免污染全局命名空间。
class MaterialPreset:
	## 预设的唯一标识符（如 "slime_1"）
	## 用于在注册表中查找预设、配置文件中持久化材质选择
	var id: String

	## 预设的显示名称（如 "1号史莱姆(普通)"）
	## 用于UI下拉菜单、设置界面等用户可见的地方
	var name: String

	## 预设的描述文本
	## 用于提示信息、工具提示等场景
	var description: String = ""

	## Shader参数字典
	## 键为参数名称（String），值为参数值（任意类型）
	## 例如: { "flow_speed": 0.5, "color_tint": Color.BLUE }
	## 留作扩展使用，当前默认预设暂不使用此字段
	var parameters: Dictionary = {}

	## 构造函数
	## 【参数】
	##   preset_id: String - 预设唯一标识符
	##   preset_name: String - 预设的友好显示名称
	func _init(preset_id: String, preset_name: String):
		id = preset_id
		name = preset_name

	## 将预设序列化为字典（用于保存配置）
	## 【返回值】 Dictionary - 包含 id、name、description、parameters 的字典
	## 【注意】parameters 使用 duplicate() 深拷贝，避免外部修改影响内部数据
	func to_dict() -> Dictionary:
		var data: Dictionary = {
			"id": id,
			"name": name,
			"description": description,
			"parameters": parameters.duplicate()
		}
		return data

	## 从字典恢复预设数据（用于加载配置）
	## 【参数】
	##   data: Dictionary - 包含预设各字段的字典
	## 【注意】使用 get() 并提供默认值，保证缺失字段时不报错
	func from_dict(data: Dictionary):
		id = data.get("id", id)
		name = data.get("name", name)
		description = data.get("description", description)
		parameters = data.get("parameters", {}).duplicate()


## =========================================================================
## MaterialRegistry — 材质预设注册表（内部类）
## =========================================================================
## 【用途】
##   维护所有可用材质预设的字典（id → MaterialPreset），支持注册、
##   查找、遍历等操作。
## 【为什么用字典（Dictionary）存储？】
##   以id为键的字典可以实现O(1)的查找效率，适合频繁根据id查找
##   预设的场景（如配置加载时根据id恢复材质）。
class MaterialRegistry:
	## 预设字典：键为预设id（String），值为 MaterialPreset 实例
	var presets: Dictionary = {}

	## 注册一个材质预设
	## 【参数】
	##   preset: MaterialPreset - 要注册的预设对象
	## 【注意】如果已存在相同id的预设，将被覆盖（后者优先）
	func register_preset(preset):
		presets[preset.id] = preset
		print("[MaterialRegistry] Registered preset: ", preset.name)

	## 根据id获取预设
	## 【参数】
	##   id: String - 预设的唯一标识符
	## 【返回值】 MaterialPreset 或 null（id不存在时）
	func get_preset(id: String):
		return presets.get(id, null)

	## 获取所有预设id的数组
	## 【返回值】 Array[String] - 所有已注册预设的id列表
	func get_all_preset_names() -> Array:
		return presets.keys()

	## 获取所有预设对象的数组
	## 【返回值】 Array[MaterialPreset] - 所有已注册的预设实例列表
	func get_all_presets() -> Array:
		return presets.values()


## =========================================================================
## MaterialManager 主体
## =========================================================================

## 材质注册表实例，维护所有可用的材质预设
var registry = null

## 目标精灵引用——材质将被应用到该精灵上
## 由 init() 方法设置，在 apply_preset() 中使用
var target_sprite: Sprite2D = null

## 当前激活的材质预设（MaterialPreset实例）
## 为null表示尚未应用任何预设
var current_preset = null

## 当前激活的着色器材质（ShaderMaterial实例）
## 这是实际驱动精灵渲染效果的Shader资源包装器
var current_material: ShaderMaterial = null


## 构造函数
## 【核心逻辑】
##   创建注册表并注册内置的默认材质预设。
##   预设注册应在对象创建时就完成，确保后续立即可用。
func _init():
	registry = MaterialRegistry.new()
	_register_default_presets()


## 初始化——设置目标精灵
## 【参数】
##   sprite: Sprite2D - 材质将要应用到的精灵节点
## 【注意】此方法必须在使用 apply_preset() 之前调用，否则会报错
func init(sprite: Sprite2D):
	target_sprite = sprite


## 注册所有内置的默认材质预设
## 【核心逻辑】
##   创建并注册项目默认包含的材质预设。
##   如需添加新材质，在此方法中添加新的 MaterialPreset 并 register_preset()。
func _register_default_presets():
	# 1号史莱姆（普通）- 默认基础材质
	# 使用 slime.gdshader 着色器实现动态流动的蓝色史莱姆效果
	var slime_1 = MaterialPreset.new("slime_1", "1号史莱姆(普通)")
	slime_1.description = "基础蓝色史莱姆材质，支持动态流动效果"
	registry.register_preset(slime_1)

	# 2号史莱姆（液态玻璃）- 玻璃特效材质
	# 携带液态玻璃渲染器，实现透明/折射/模糊视觉效果
	var slime_2 = MaterialPreset.new("slime_2", "2号史莱姆(液态玻璃)")
	slime_2.description = "透明水滴质感，支持折射/模糊/光晕效果"
	registry.register_preset(slime_2)

	# 3号史莱姆（金属）- 占位（需要 shader 支持）
	var slime_3 = MaterialPreset.new("slime_3", "3号史莱姆(金属)")
	slime_3.description = "金属质感史莱姆，表面有反光效果（待 shader 支持）"
	registry.register_preset(slime_3)

	# 4号史莱姆（冰晶）- 占位（需要 shader 支持）
	var slime_4 = MaterialPreset.new("slime_4", "4号史莱姆(冰晶)")
	slime_4.description = "冰晶/冰块质感，透明带碎裂反光（待 shader 支持）"
	registry.register_preset(slime_4)

	# 5号史莱姆（火焰）- 占位（需要 shader 支持）
	var slime_5 = MaterialPreset.new("slime_5", "5号史莱姆(火焰)")
	slime_5.description = "火焰/熔岩质感，内部有流动光效（待 shader 支持）"
	registry.register_preset(slime_5)


## 应用材质预设（入口方法，自动分发）
## 【参数】
##   preset - 可以是 MaterialPreset 对象 或 Dictionary
## 【核心逻辑】
##   自动判断参数类型：
##   - MaterialPreset对象 → 调用 _apply_preset_object()
##   - Dictionary → 调用 apply_preset_dict()
##   - 其他类型 → 打印错误信息
## 【为什么需要两个分支？】
##   材质预设可能来自两个来源：
##   1. 运行时UI选择（传入MaterialPreset对象）
##   2. 配置文件反序列化（传入Dictionary）
##   统一入口方法简化了调用方的代码。
func apply_preset(preset):
	if not target_sprite:
		print("[MaterialManager] Error: Target sprite not set")
		return

	if preset != null and typeof(preset) == TYPE_OBJECT and "id" in preset:
		_apply_preset_object(preset)
	elif typeof(preset) == TYPE_DICTIONARY:
		apply_preset_dict(preset)
	else:
		print("[MaterialManager] Error: Invalid preset type")


## 获取指定预设对应的Shader资源
## 【参数】
##   _preset_id: String - 预设id（当前版本未使用，但保留为扩展点）
## 【返回值】 Resource - load() 返回的 Shader 资源
## 【为什么使用 preload()？】
##   preload() 在脚本编译时加载资源，运行时零开销。
##   当前只有一个Shader，所以忽略预设id参数直接返回。
##   将来若有多种Shader，可在此方法中根据 preset_id 分发。
func _get_shader_for_preset(_preset_id: String) -> Resource:
	return preload("res://modules/display/shaders/slime.gdshader")


## 应用 MaterialPreset 对象到目标精灵
## 【参数】
##   preset: MaterialPreset - 要应用的材质预设对象
## 【核心逻辑】
##   1. 保存当前预设引用
##   2. 创建新的 ShaderMaterial 实例
##   3. 加载对应的 Shader 并设置到材质上
##   4. 将材质赋值给目标精灵的 .material 属性
## 【注意】
##   每次应用都创建新的 ShaderMaterial 实例，这是为了确保材质状态
##   干净——不会残留上一预设的参数设置。
func _apply_preset_object(preset):
	current_preset = preset

	current_material = ShaderMaterial.new()
	current_material.shader = _get_shader_for_preset(preset.id)

	target_sprite.material = current_material
	print("[MaterialManager] Applied preset: ", preset.name)


## 从字典数据应用材质预设（反序列化还原）
## 【参数】
##   preset_data: Dictionary - 包含预设数据的字典（通常来自配置文件）
## 【核心逻辑】
##   1. 检查目标精灵是否存在
##   2. 从字典中提取预设id（默认使用 "slime_1"）
##   3. 加载对应的Shader（注意：不设置 current_preset，因为字典不是完整预设对象）
##   4. 创建 ShaderMaterial 并应用到精灵
## 【边界情况】
##   - target_sprite 为 null → 打印错误并返回
##   - 字典中无 id 字段 → 默认使用 "slime_1"
func apply_preset_dict(preset_data: Dictionary):
	if not target_sprite:
		print("[MaterialManager] Error: Target sprite not set")
		return

	current_material = ShaderMaterial.new()

	var preset_id = preset_data.get("id", "slime_1")
	current_material.shader = _get_shader_for_preset(preset_id)

	target_sprite.material = current_material
	print("[MaterialManager] Applied preset dict: ", preset_id)


## 开关呼吸效果（顶点形变）
## 【参数】
##   enabled: bool - true启用整体晃动，false静止
func set_breathing_enabled(enabled: bool):
	if current_material:
		current_material.set_shader_parameter("enable_breathing", enabled)
		print("[MaterialManager] Breathing ", "enabled" if enabled else "disabled")


## 开关动效（材质内部扰动）
## 【参数】
##   enabled: bool - true启用噪声扰动，false静态纹理
func set_motion_effect_enabled(enabled: bool):
	if current_material:
		current_material.set_shader_parameter("enable_motion_effect", enabled)
		print("[MaterialManager] Motion effect ", "enabled" if enabled else "disabled")


## 开关动态效果（兼容旧接口，同时控制呼吸和动效）
func set_dynamic_enabled(enabled: bool):
	set_breathing_enabled(enabled)
	set_motion_effect_enabled(enabled)


## 获取当前材质的显示名称
## 【返回值】 String - 当前预设的名称，未设置时返回默认值
## 【用途】用于UI标题栏、状态显示等
func get_current_material_name() -> String:
	if current_preset:
		return current_preset.name
	return "1号史莱姆(普通)"


## 获取当前激活的材质预设对象
## 【返回值】 MaterialPreset 或 null
func get_current_preset():
	return current_preset


## 获取当前激活的 ShaderMaterial
## 【返回值】 ShaderMaterial 或 null
func get_current_material() -> ShaderMaterial:
	return current_material


## 根据id从注册表中查找预设
## 【参数】
##   id: String - 预设唯一标识符
## 【返回值】 MaterialPreset 或 null
func get_preset_by_id(id: String):
	return registry.get_preset(id)


## 获取所有已注册的预设
## 【返回值】 Array[MaterialPreset]
func get_all_presets() -> Array:
	return registry.get_all_presets()
