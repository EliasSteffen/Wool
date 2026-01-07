class_name GameOverScreen
extends Control

var _can_interact: bool = false

func _ready() -> void:
	# Start invisible
	modulate.a = 0.0

	# Fade in over 1 second (adjusted for time_scale in BasePlayer)
	# If time_scale is 0.5, 0.5s duration = 1.0s real time
	var duration = 0.5 if Engine.time_scale != 1.0 else 1.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): _can_interact = true)

func _input(event: InputEvent) -> void:
	if not _can_interact:
		return

	if (event is InputEventKey and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventJoypadButton and event.pressed):
		_return_to_main_menu()

func _return_to_main_menu() -> void:
	# Prevent double firing
	_can_interact = false
	# Reset time scale
	Engine.time_scale = 1.0

	# Clean up the overlay (CanvasLayer)
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()

	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
