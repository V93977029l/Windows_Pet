extends Node

## ============================================================================
## core/autoload/event_bus.gd — 全局事件总线
## ============================================================================
## 【架构定位】
##   这是整个模块化架构的解耦核心。所有模块间的通信都应通过
##   EventBus 进行，而非直接引用。采用发布-订阅模式（Pub-Sub），
##   事件的发布者无需知道谁在监听，监听者也无需知道谁在发布。
##
## 【使用方式】
##   发布事件: EventBus.publish("event_name", payload_data)
##   订阅事件: EventBus.subscribe("event_name", _on_event_handler)
##   取消订阅: EventBus.unsubscribe("event_name", _on_event_handler)
##
## 【最佳实践】
##   1. 事件名称使用 snake_case，清晰描述发生了什么
##   2. payload 建议使用 Dictionary 以保持可扩展性
##   3. 在 _exit_tree() 中取消订阅，防止内存泄漏
##   4. 避免在回调中发布同步事件链，防止无限循环
## ============================================================================

var _listeners: Dictionary = {}

## 订阅事件
## @param event_name: 事件名称，建议 snake_case 格式
## @param callback: 回调函数，接收一个可选的 payload 参数
func subscribe(event_name: String, callback: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	var arr: Array = _listeners[event_name]
	if not arr.has(callback):
		arr.append(callback)

## 取消订阅事件
## @param event_name: 事件名称
## @param callback: 之前订阅时使用的同一个回调函数
func unsubscribe(event_name: String, callback: Callable) -> void:
	if not _listeners.has(event_name):
		return
	var arr: Array = _listeners[event_name]
	var idx := arr.find(callback)
	if idx != -1:
		arr.remove_at(idx)
	if arr.is_empty():
		_listeners.erase(event_name)

## 发布事件
## @param event_name: 事件名称
## @param payload: 传递给监听者的数据（可选），建议使用 Dictionary
func publish(event_name: String, payload = null) -> void:
	if not _listeners.has(event_name):
		return
	var arr: Array = _listeners[event_name].duplicate()
	for cb in arr:
		if payload != null:
			cb.call(payload)
		else:
			cb.call()

## 检查某个事件是否有监听者
func has_listeners(event_name: String) -> bool:
	return _listeners.has(event_name) and not _listeners[event_name].is_empty()

## 清除某个事件的所有监听者
func clear_event(event_name: String) -> void:
	_listeners.erase(event_name)

## 清除所有事件的所有监听者（慎用）
func clear_all() -> void:
	_listeners.clear()
