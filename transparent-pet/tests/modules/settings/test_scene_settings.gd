class_name TestSceneSettings
extends GdUnitTestSuite

const SETTINGS_SCENE := preload("res://modules/settings/ui/settings_window.tscn")


func test_root_is_window() -> void:
	var instance := SETTINGS_SCENE.instantiate()
	add_child(instance)

	assert_str(instance.name).is_equal("SettingsWindow")
	assert_that(instance).is_instanceof(Window)

	instance.queue_free()


func test_has_scale_slider() -> void:
	var instance := SETTINGS_SCENE.instantiate()
	add_child(instance)

	var slider := instance.get_node_or_null("Background/MainHBox/CenterVBox/Scale/HBox2/Slider2")
	assert_that(slider).is_not_null()
	assert_that(slider).is_instanceof(HSlider)

	instance.queue_free()


func test_has_save_and_reset_buttons() -> void:
	var instance := SETTINGS_SCENE.instantiate()
	add_child(instance)

	var save_btn := instance.get_node_or_null("Background/MainHBox/CenterVBox/Buttons/Save")
	var reset_btn := instance.get_node_or_null("Background/MainHBox/CenterVBox/Buttons/Reset")

	assert_that(save_btn).is_not_null()
	assert_that(reset_btn).is_not_null()

	instance.queue_free()


func test_has_material_combo() -> void:
	var instance := SETTINGS_SCENE.instantiate()
	add_child(instance)

	var combo := instance.get_node_or_null("Background/MainHBox/CenterVBox/Material/Combo")
	assert_that(combo).is_not_null()
	assert_that(combo).is_instanceof(OptionButton)

	instance.queue_free()
