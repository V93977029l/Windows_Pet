class_name PetUIApi
extends Node

@warning_ignore("unused_signal")
signal settings_opened()
@warning_ignore("unused_signal")
signal settings_closed()
@warning_ignore("unused_signal")
signal throw_settings_opened()
@warning_ignore("unused_signal")
signal throw_settings_closed()

func init(_pet_core_ref):
	push_error("[PetUI] init() must be overridden")

func open_settings():
	push_error("[PetUI] open_settings() must be overridden")

func open_throw_settings():
	push_error("[PetUI] open_throw_settings() must be overridden")
