class_name TestConfigManager
extends GdUnitTestSuite

var _manager: Node


func before_test() -> void:
	_manager = load("res://core/autoload/config_manager.gd").new()
	add_child(_manager)


func after_test() -> void:
	if _manager:
		_manager.queue_free()


# ── cfg_get ──

func test_cfg_get_returns_default_when_no_configs() -> void:
	assert_int(_manager.cfg_get("test_section", "test_key", 42)).is_equal(42)
	assert_str(_manager.cfg_get("test_section", "test_key", "fallback")).is_equal("fallback")


func test_cfg_get_returns_default_config_value() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	assert_float(_manager.cfg_get("pet", "pet_scale", 2.0)).is_equal(1.0)


func test_cfg_get_user_overrides_default() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	_manager._user_configs["test_module"].set_value("pet", "pet_scale", 3.0)
	assert_float(_manager.cfg_get("pet", "pet_scale", 2.0)).is_equal(3.0)


func test_cfg_get_falls_back_to_default_when_key_not_in_user() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	_manager._user_configs["test_module"].set_value("pet", "other_key", 99)
	assert_float(_manager.cfg_get("pet", "pet_scale", 2.0)).is_equal(1.0)


func test_cfg_get_returns_default_value_when_section_not_found() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	assert_int(_manager.cfg_get("nonexistent_section", "key", 100)).is_equal(100)


# ── cfg_set ──

func test_cfg_set_persists_different_value() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	_manager.cfg_set("pet", "pet_scale", 5.0)
	assert_float(_manager.cfg_get("pet", "pet_scale", 2.0)).is_equal(5.0)


func test_cfg_set_erases_when_equal_to_default() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	# 先设置一个不同的值
	_manager.cfg_set("pet", "pet_scale", 5.0)
	assert_float(_manager.cfg_get("pet", "pet_scale", 2.0)).is_equal(5.0)

	# 设置回默认值，应该被擦除
	_manager.cfg_set("pet", "pet_scale", 1.0)
	assert_float(_manager.cfg_get("pet", "pet_scale", 1.0)).is_equal(1.0)
	# 验证用户配置中该键已被擦除
	assert_bool(_manager._user_configs["test_module"].has_section_key("pet", "pet_scale")).is_false()


func test_cfg_set_noop_when_no_matching_module() -> void:
	# 没有加载任何模块时，cfg_set 应安全返回
	_manager.cfg_set("unknown", "key", 123)
	assert_int(_manager.cfg_get("unknown", "key", -1)).is_equal(-1)


func test_cfg_set_float_approx_equality() -> void:
	_populate_module("physics", "gravity", 800.0)
	# 设置与默认非常接近的浮点值，应视为相等
	_manager.cfg_set("physics", "gravity", 800.0 + 0.0000001)
	assert_float(_manager.cfg_get("physics", "gravity", 0.0)).is_equal(800.0)
	assert_bool(_manager._user_configs["test_module"].has_section_key("physics", "gravity")).is_false()


# ── save_config ──

func test_save_config_creates_directory() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	_manager._user_configs["test_module"].set_value("pet", "pet_scale", 3.0)

	# save_config 不应崩溃
	_manager.save_config()


# ── _find 内部方法 ──

func test_find_user_config_returns_config_for_known_section() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	var result = _manager._find_user_config("pet")
	assert_that(result).is_not_null()


func test_find_user_config_returns_null_for_unknown_section() -> void:
	assert_that(_manager._find_user_config("nonexistent")).is_null()


func test_find_default_returns_value_for_known_key() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	var result = _manager._find_default("pet", "pet_scale")
	assert_float(result).is_equal(1.0)


func test_find_default_returns_null_for_unknown_key() -> void:
	_populate_module("pet", "pet_scale", 1.0)
	var result = _manager._find_default("pet", "nonexistent_key")
	assert_that(result).is_null()


# ── 辅助方法 ──

func _populate_module(section: String, key: String, value) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value(section, key, value)
	_manager._default_configs["test_module"] = cfg
	_manager._user_configs["test_module"] = ConfigFile.new()
