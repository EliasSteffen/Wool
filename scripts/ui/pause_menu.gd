extends BaseMenu

@onready var resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var dev_settings_button: Button = $Control/CenterContainer/VBoxContainer/DevSettingsButton

func _ready() -> void:
	super._ready()
	resume_button.pressed.connect(_on_resume_pressed)
	dev_settings_button.pressed.connect(_on_dev_settings_pressed)

	# Ensure modern rounded styling on menu buttons (register_buttons will also style)
	var UITheme = preload("res://scripts/ui/ui_theme.gd")
	UITheme.apply_modern_button_style(resume_button)
	UITheme.apply_modern_button_style(dev_settings_button)

	register_buttons([resume_button, dev_settings_button])

func _on_resume_pressed() -> void:
	GameManager.toggle_pause()
