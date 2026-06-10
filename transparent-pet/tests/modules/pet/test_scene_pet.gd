class_name TestScenePet
extends GdUnitTestSuite

const PET_SCENE := preload("res://modules/pet/scenes/pet.tscn")


func test_pet_root_is_node2d() -> void:
	var instance := PET_SCENE.instantiate()
	add_child(instance)

	assert_str(instance.name).is_equal("PetRoot")
	assert_that(instance).is_instanceof(Node2D)

	instance.queue_free()


func test_pet_has_slime_sprite() -> void:
	var instance := PET_SCENE.instantiate()
	add_child(instance)

	var slime := instance.get_node_or_null("Slime")
	assert_that(slime).is_not_null()
	assert_that(slime).is_instanceof(Sprite2D)

	instance.queue_free()


func test_slime_has_texture() -> void:
	var instance := PET_SCENE.instantiate()
	add_child(instance)

	var slime := instance.get_node_or_null("Slime")
	assert_that(slime).is_not_null()
	if slime is Sprite2D:
		assert_that(slime.texture).is_not_null()

	instance.queue_free()


func test_pet_has_script_attached() -> void:
	var instance := PET_SCENE.instantiate()
	add_child(instance)

	assert_that(instance.get_script()).is_not_null()

	instance.queue_free()
