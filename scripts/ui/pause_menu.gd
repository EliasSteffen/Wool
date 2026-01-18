extends BaseMenu

@onready var resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Control/CenterContainer/VBoxContainer/SettingsButton

func _ready() -> void:
	super._ready()
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	# Ensure modern rounded styling on menu buttons (register_buttons will also style)
	var UITheme = preload("res://scripts/ui/ui_theme.gd")
	# Apply normal modern style to resume and ensure it sizes like other UI buttons
	resume_button.custom_minimum_size = Vector2(resume_button.custom_minimum_size.x, 96)
	UITheme.apply_modern_button_style(resume_button, Vector2(0, 96), false)
	# Use Button's built-in icon + text features for consistent sizing
	var play_icon: Texture2D = preload("res://assets/ui/play.svg")
	resume_button.icon = play_icon
	resume_button.text = "Resume"
	# Ensure icon and text scale well for the button height
	resume_button.add_theme_constant_override("icon_size", 48)
	resume_button.add_theme_font_size_override("font_size", 28)

	# Settings button: use icon + text (matches Resume style)
	settings_button.custom_minimum_size = Vector2(settings_button.custom_minimum_size.x, 96)
	UITheme.apply_modern_button_style(settings_button, Vector2(0, 96), false)
	var icon: Texture2D = preload("res://assets/ui/settings.svg")
	settings_button.icon = icon
	settings_button.text = "Settings"
	settings_button.add_theme_constant_override("icon_size", 48)
	settings_button.add_theme_font_size_override("font_size", 28)

	register_buttons([resume_button, settings_button])

func _on_resume_pressed() -> void:
	GameManager.toggle_pause()
