extends Control

@onready var content: Control = $Background/ScrollContent/VBoxContainer
@onready var close_button: Button = $CloseButton
@onready var background: Control = $Background

var scroll_speed: float = 60.0
var _initial_y: float = 0.0

func _ready() -> void:
	# --- PAPER BACKGROUND SETUP ---
	# Handled by TextureRect in Scene "BackgroundImage"
	pass

	# Start below the visible area
	if content:
		# content 'position' is relative to ScrollContent.
		# ScrollContent is parented to Background (Panel) and anchors 15 (Full Rect).
		# We want text to appear from the BOTTOM of the Background panel.
		# Since ScrollContent fills Background, its size.y is roughly the Background's size.y.
		# We want to start at that Y position so it scrolls up INTO view.

		# Use call_deferred to ensure layout is complete and sizes are valid
		call_deferred("_reset_position")

func _reset_position():
	if content:
		# content.position.y is local to ScrollContent.
		# If we set it to ScrollContent.size.y, it starts at the bottom edge.
		# Since ScrollContent clips interactively (clip_contents=true in Tscn),
		# It will appear to slide up from the bottom edge.
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
		# Content height + position.y < 0 means the bottom of content is above top of screen
		# We use -100 buffer.
		if content.position.y + content.size.y < -100:
			call_deferred("_reset_position")

func _on_close_button_pressed() -> void:
	queue_free()
