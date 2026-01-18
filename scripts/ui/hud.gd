extends CanvasLayer

@onready var pause_button: Button = $PauseButton

func _ready() -> void:
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
		var UITheme = preload("res://scripts/ui/ui_theme.gd")
		# Use a slightly larger circular icon for better visibility
		UITheme.apply_modern_button_style(pause_button, Vector2(80, 80), true)
		# Make button background transparent (icon only)
		var flat_style := StyleBoxFlat.new()
		flat_style.bg_color = Color(0,0,0,0)
		flat_style.corner_radius_top_left = 0
		flat_style.corner_radius_top_right = 0
		flat_style.corner_radius_bottom_left = 0
		flat_style.corner_radius_bottom_right = 0
		pause_button.add_theme_stylebox_override("normal", flat_style)
		pause_button.add_theme_stylebox_override("hover", flat_style)

		# Clear default text and use a centered TextureRect so the icon fills the button
		pause_button.text = ""
		var pause_icon: Texture2D = preload("res://assets/ui/pause.svg")
		var icon_rect: TextureRect = pause_button.get_node_or_null("IconTex") as TextureRect
		if not icon_rect:
			icon_rect = TextureRect.new()
			icon_rect.name = "IconTex"
			pause_button.add_child(icon_rect)
			icon_rect.anchor_left = 0.0
			icon_rect.anchor_top = 0.0
			icon_rect.anchor_right = 1.0
			icon_rect.anchor_bottom = 1.0
			icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		icon_rect.texture = pause_icon
		# Ensure icon is visible; sizing and anchors keep it centered
		icon_rect.modulate = Color(1, 1, 1)
func _on_pause_pressed() -> void:
	GameManager.toggle_pause()
