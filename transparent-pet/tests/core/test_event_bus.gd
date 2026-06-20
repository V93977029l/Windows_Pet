class_name TestEventBus
extends GdUnitTestSuite

var _event_bus: Node
var _received_count: int
var _received_payload

func before_test() -> void:
	_event_bus = load("res://core/autoload/event_bus.gd").new()
	add_child(_event_bus)
	_received_count = 0
	_received_payload = null

func after_test() -> void:
	if _event_bus:
		_event_bus.queue_free()
	_received_count = 0
	_received_payload = null


func on_event_received(payload = null) -> void:
	_received_count += 1
	_received_payload = payload


func test_subscribe_and_publish() -> void:
	var event_name := "test_event_1"
	_event_bus.subscribe(event_name, on_event_received)
	assert_that(_event_bus.has_listeners(event_name)).is_true()

	_event_bus.publish(event_name)
	assert_int(_received_count).is_equal(1)


func test_publish_with_payload() -> void:
	var event_name := "test_event_2"
	var payload := {"key": "value", "num": 42}
	_event_bus.subscribe(event_name, on_event_received)

	_event_bus.publish(event_name, payload)
	assert_int(_received_count).is_equal(1)
	assert_that(_received_payload).is_not_null()
	assert_str(_received_payload.key).is_equal("value")
	assert_int(_received_payload.num).is_equal(42)


func test_multiple_subscribers() -> void:
	var event_name := "test_event_3"
	var counter := {"count": 0}

	var second_handler := func(_payload = null):
		counter["count"] += 1

	_event_bus.subscribe(event_name, on_event_received)
	_event_bus.subscribe(event_name, second_handler)

	_event_bus.publish(event_name)
	assert_int(_received_count).is_equal(1)
	assert_int(counter["count"]).is_equal(1)


func test_unsubscribe() -> void:
	var event_name := "test_event_4"
	_event_bus.subscribe(event_name, on_event_received)
	assert_that(_event_bus.has_listeners(event_name)).is_true()

	_event_bus.unsubscribe(event_name, on_event_received)
	assert_that(_event_bus.has_listeners(event_name)).is_false()

	_event_bus.publish(event_name)
	assert_int(_received_count).is_equal(0)


func test_publish_with_no_subscribers() -> void:
	_event_bus.publish("nonexistent_event")
	assert_int(_received_count).is_equal(0)


func test_clear_event() -> void:
	var event_name := "test_event_5"
	_event_bus.subscribe(event_name, on_event_received)
	_event_bus.clear_event(event_name)

	assert_that(_event_bus.has_listeners(event_name)).is_false()


func test_clear_all() -> void:
	_event_bus.subscribe("event_a", on_event_received)
	_event_bus.subscribe("event_b", on_event_received)
	_event_bus.clear_all()

	assert_that(_event_bus.has_listeners("event_a")).is_false()
	assert_that(_event_bus.has_listeners("event_b")).is_false()


func test_double_subscribe_same_callback() -> void:
	var event_name := "test_event_6"
	_event_bus.subscribe(event_name, on_event_received)
	_event_bus.subscribe(event_name, on_event_received)

	_event_bus.publish(event_name)
	assert_int(_received_count).is_equal(1)
