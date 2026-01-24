extends Control

@onready var content: Control = $PerspectiveContainer/SubViewport/Content/VBoxContainer
@onready var close_button: Button = $CloseButton

var scroll_speed: float = 60.0
var _initial_y: float = 0.0

func _ready() -> void:
    # Apply button style
	if has_node("CloseButton"):
		var btn = get_node("CloseButton")

		# Apply modern rounded style (base size)
		var UITheme = preload("res://scripts/ui/ui_theme.gd")
		UITheme.apply_modern_button_style(btn, Vector2(100, 100), true)

		# Make close button background transparent (icon-only style from settings)
		var flat_style := StyleBoxFlat.new()
		flat_style.bg_color = Color(0,0,0,0)
		flat_style.corner_radius_top_left = 0
		flat_style.corner_radius_top_right = 0
		flat_style.corner_radius_bottom_left = 0
		flat_style.corner_radius_bottom_right = 0
		btn.add_theme_stylebox_override("normal", flat_style)
		btn.add_theme_stylebox_override("hover", flat_style)

		# Use asset icon via TextureRect child for full control
		btn.text = ""
		var close_icon: Texture2D = preload("res://assets/ui/close-button.png")
		# Check if child exists (re-run safety)
		var close_icon_rect: TextureRect = btn.get_node_or_null("IconTex") as TextureRect
		if not close_icon_rect:
			close_icon_rect = TextureRect.new()
			close_icon_rect.name = "IconTex"
			btn.add_child(close_icon_rect)
			close_icon_rect.anchor_left = 0.0
			close_icon_rect.anchor_top = 0.0
			close_icon_rect.anchor_right = 1.0
			close_icon_rect.anchor_bottom = 1.0
			close_icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			close_icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			close_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		close_icon_rect.texture = close_icon


	# Start below the screen
	if content:
		var viewport_height = get_viewport_rect().size.y
		content.position.y = viewport_height
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
		if content.position.y + content.size.y < 0:
			content.position.y = get_viewport_rect().size.y

func _on_close_button_pressed() -> void:
	queue_free()
