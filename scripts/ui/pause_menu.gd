extends BaseMenu

@onready var resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var reset_button: Button = $Control/CenterContainer/VBoxContainer/ResetHighscoreButton
@onready var settings_button: Button = $Control/CenterContainer/VBoxContainer/SettingsButton
@onready var credits_button: Button = $Control/CenterContainer/VBoxContainer/CreditsButton

func _ready() -> void:
	super._ready()
	resume_button.pressed.connect(_on_resume_pressed)
	reset_button.pressed.connect(_on_reset_highscore_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	# Ensure modern rounded styling on menu buttons (register_buttons will also style)
	var UITheme = preload("res://scripts/ui/ui_theme.gd")
	# Apply normal modern style to resume and ensure it sizes like other UI buttons
	resume_button.custom_minimum_size = Vector2(resume_button.custom_minimum_size.x, 150)
	UITheme.apply_modern_button_style(resume_button, Vector2(0, 150), false)
	resume_button.text = "Resume"
	resume_button.add_theme_font_size_override("font_size", 36)

	# Reset Button style
	reset_button.custom_minimum_size = Vector2(reset_button.custom_minimum_size.x, 150)
	UITheme.apply_modern_button_style(reset_button, Vector2(0, 150), false)
	reset_button.text = "Reset Highscore"
	reset_button.add_theme_font_size_override("font_size", 36)

	# Settings button: use icon + text (matches Resume style)
	settings_button.custom_minimum_size = Vector2(settings_button.custom_minimum_size.x, 150)
	UITheme.apply_modern_button_style(settings_button, Vector2(0, 150), false)
	settings_button.text = "Settings"
	settings_button.add_theme_font_size_override("font_size", 36)

	register_buttons([resume_button, reset_button, settings_button, credits_button])

	setup_credits_button()

func setup_credits_button() -> void:
	credits_button.pressed.connect(_on_credits_pressed)

	credits_button.custom_minimum_size = Vector2(credits_button.custom_minimum_size.x, 150)
	var UITheme = preload("res://scripts/ui/ui_theme.gd")
	UITheme.apply_modern_button_style(credits_button, Vector2(0, 150), false)
	credits_button.text = "Credits"
	credits_button.add_theme_font_size_override("font_size", 36)

func _on_credits_pressed() -> void:
	var credits_scene = preload("res://scenes/ui/credits.tscn").instantiate()
	add_child(credits_scene)


func _on_resume_pressed() -> void:
	GameManager.toggle_pause()

func _on_reset_highscore_pressed() -> void:
	GameManager.reset_highscore()
	# Optional: Give feedback, e.g. change text
	reset_button.text = "Highscore Reset!"
	reset_button.disabled = true
