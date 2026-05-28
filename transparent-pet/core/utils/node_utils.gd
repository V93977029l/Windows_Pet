class_name NodeUtils

## 从脚本路径创建实例（load + new，失败时返回 null）
static func create_instance(script_path: String) -> Variant:
	var script := load(script_path)
	if not script:
		push_error("[NodeUtils] 无法加载脚本: ", script_path)
		return null
	return script.new()

## 创建实例并调用 init() 初始化（组合 load + new + init 三步为一步）
## @param init_args: 传递给 init() 的参数数组，按顺序匹配
static func create_and_init(script_path: String, init_args: Array = []) -> Variant:
	var instance: Variant = create_instance(script_path)
	if instance and instance.has_method("init"):
		instance.init.callv(init_args)
	return instance

## 从场景路径实例化场景（load + instantiate，失败时返回 null）
static func instantiate_scene(scene_path: String) -> Node:
	var scene := load(scene_path)
	if not scene:
		push_error("[NodeUtils] 无法加载场景: ", scene_path)
		return null
	return scene.instantiate()
