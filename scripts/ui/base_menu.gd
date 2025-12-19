class_name BaseMenu
extends Node

const DEV_SETTINGS_SCENE = preload("res://scenes/ui/dev_settings_window.tscn")

var _dev_settings_instance: Node = null
var _buttons_to_resize: Array[Control] = []

func _ready() -> void:
	get_tree().root.size_changed.connect(_update_button_sizes)
	# Defer to ensure all children are ready and registered
	call_deferred("_update_button_sizes")

func register_buttons(buttons: Array[Control]) -> void:
	_buttons_to_resize.append_array(buttons)
	_update_button_sizes()

func _update_button_sizes() -> void:
	var width := get_viewport().get_visible_rect().size.x / 8.0
	for btn in _buttons_to_resize:
		if is_instance_valid(btn):
			btn.custom_minimum_size.x = width

func _on_dev_settings_pressed() -> void:
	if not _dev_settings_instance:
		_dev_settings_instance = DEV_SETTINGS_SCENE.instantiate()
		get_tree().root.add_child(_dev_settings_instance)

	if _dev_settings_instance.has_method("open"):
		_dev_settings_instance.open()
	else:
		_dev_settings_instance.show()
