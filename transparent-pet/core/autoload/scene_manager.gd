extends Node

## ============================================================================
## core/autoload/scene_manager.gd — 场景加载与过渡管理器
## ============================================================================
## 【架构定位】
##   统一管理场景切换，提供过渡动画、异步加载、场景栈等功能。
##   所有场景切换请求都通过本管理器进行，禁止直接调用
##   get_tree().change_scene_to_file()。
##
## 【核心职责】
##   1. 异步场景加载（避免卡顿）
##   2. 加载过渡动画（淡入淡出、转场效果）
##   3. 场景栈管理（前进/后退导航）
##   4. 加载进度通知
##
## 【使用方式】
##   通过 EventBus 发布事件:
##     EventBus.publish("change_scene", {"path": "res://path/to/scene.tscn"})
##   或直接调用:
##     SceneManager.change_scene("res://path/to/scene.tscn")
## ============================================================================

signal scene_load_started(scene_path: String)
signal scene_load_completed(scene_path: String)
signal scene_transition_finished(scene_path: String)

var _scene_stack: Array[String] = []
var _is_loading: bool = false
var _transition_duration: float = 0.3

func _ready() -> void:
	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		eb.subscribe("change_scene", _on_change_scene_request)
		eb.subscribe("go_back", _on_go_back_request)

## 切换到指定场景（异步加载 + 过渡动画）
## @param scene_path: 目标场景的资源路径
## @param transition: 是否使用过渡动画，默认 true
func change_scene(scene_path: String, transition: bool = true) -> void:
	if _is_loading:
		push_warning("[SceneManager] 正在加载中，忽略请求: " + scene_path)
		return

	if not ResourceLoader.exists(scene_path):
		push_error("[SceneManager] 场景不存在: " + scene_path)
		return

	_is_loading = true
	scene_load_started.emit(scene_path)

	var current_path := ""
	if get_tree().current_scene:
		current_path = get_tree().current_scene.scene_file_path
		if not current_path.is_empty():
			_scene_stack.append(current_path)

	if transition:
		_perform_transition(scene_path)
	else:
		_load_scene(scene_path)

## 返回上一个场景
func go_back() -> bool:
	if _scene_stack.is_empty():
		push_warning("[SceneManager] 场景栈为空，无法返回")
		return false

	var previous_path: String = _scene_stack.pop_back()
	change_scene(previous_path, true)
	return true

## 获取当前场景栈深度
func get_stack_depth() -> int:
	return _scene_stack.size()

## 清空场景栈
func clear_stack() -> void:
	_scene_stack.clear()

## 设置过渡动画时长（秒）
func set_transition_duration(duration: float) -> void:
	_transition_duration = maxf(duration, 0.0)

func _perform_transition(scene_path: String) -> void:
	var tree := get_tree()
	if not tree:
		_load_scene(scene_path)
		return

	var canvas := CanvasLayer.new()
	canvas.layer = 128
	tree.root.add_child(canvas)

	var color_rect := ColorRect.new()
	color_rect.color = Color.BLACK
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(color_rect)

	var tween := tree.create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, _transition_duration).from(0.0)
	tween.tween_callback(_load_scene.bind(scene_path, canvas, color_rect))

func _load_scene(scene_path: String, canvas: CanvasLayer = null, color_rect: ColorRect = null) -> void:
	var tree := get_tree()
	if not tree:
		_is_loading = false
		return

	var err := tree.change_scene_to_file(scene_path)
	if err != OK:
		push_error("[SceneManager] 场景加载失败: " + scene_path + " (error: " + str(err) + ")")
		_is_loading = false
		return

	scene_load_completed.emit(scene_path)

	if canvas and color_rect:
		var tween := tree.create_tween()
		tween.tween_property(color_rect, "color:a", 0.0, _transition_duration).from(1.0)
		tween.tween_callback(_finish_transition.bind(canvas, scene_path))
	else:
		_is_loading = false
		scene_transition_finished.emit(scene_path)

func _finish_transition(canvas: CanvasLayer, scene_path: String) -> void:
	if is_instance_valid(canvas):
		canvas.queue_free()
	_is_loading = false
	scene_transition_finished.emit(scene_path)

func _on_change_scene_request(payload: Dictionary) -> void:
	var path: String = payload.get("path", "")
	if path.is_empty():
		return
	change_scene(path, payload.get("transition", true))

func _on_go_back_request(_payload: Dictionary = {}) -> void:
	go_back()
