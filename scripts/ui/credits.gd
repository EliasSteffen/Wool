extends Control

@onready var content: Control = $Background/ScrollContent/VBoxContainer
@onready var background: Control = $Background

var scroll_speed: float = 60.0
var _initial_y: float = 0.0

func _ready() -> void:
	$Background/MenuBackground/CloseButton.pressed.connect(_on_close_button_pressed)

	# Start below the visible area
	if content:
		call_deferred("_reset_position")

func _reset_position():
	if content:
		if content.get_parent() is Control:
			content.position.y = content.get_parent().size.y
		else:
			content.position.y = get_viewport_rect().size.y

		_initial_y = content.position.y

	# Switch music
	AudioManager.play_credits_music()

func _exit_tree() -> void:
	AudioManager.play_main_music()

func _process(delta: float) -> void:
	if content:
		var current_speed = scroll_speed

		# Check for hold input (Left Mouse or Touch)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			current_speed *= 4.0

		content.position.y -= current_speed * delta

		# Reset if it goes too far up (off screen top)
		if content.position.y + content.size.y < -100:
			call_deferred("_reset_position")

func _on_close_button_pressed() -> void:
	queue_free()
