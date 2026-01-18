class_name BaseMenu
extends Node

const SETTINGS_SCENE = preload("res://scenes/ui/settings_window.tscn")

var _settings_instance: Node = null
var _buttons_to_resize: Array[Control] = []

# UI theme helper
var UITheme = preload("res://scripts/ui/ui_theme.gd")

func _ready() -> void:
	get_tree().root.size_changed.connect(_update_button_sizes)
	# Defer to ensure all children are ready and registered
	call_deferred("_update_button_sizes")

func register_buttons(buttons: Array[Control]) -> void:
	# Apply sizing and modern rounded styles to registered buttons
	_buttons_to_resize.append_array(buttons)
	for btn in buttons:
		if btn and btn is Button:
			UITheme.apply_modern_button_style(btn)
	_update_button_sizes()

func _update_button_sizes() -> void:
	var width := get_viewport().get_visible_rect().size.x / 8.0
	for btn in _buttons_to_resize:
		if is_instance_valid(btn):
			btn.custom_minimum_size.x = width

func _on_settings_pressed() -> void:
	if not _settings_instance:
		_settings_instance = SETTINGS_SCENE.instantiate()
		get_tree().root.add_child(_settings_instance)

	if _settings_instance.has_method("open"):
		_settings_instance.open()
	else:
		_settings_instance.show()
