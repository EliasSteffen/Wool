extends BaseMenu

@onready var resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Control/CenterContainer/VBoxContainer/SettingsButton
@onready var credits_button: Button = $Control/CenterContainer/VBoxContainer/CreditsButton

func _ready() -> void:
	super._ready()
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	# Buttons will use the textured theme from assets/ui/pause_theme.tres

	settings_button.text = "Settings"

	register_buttons([settings_button, credits_button], false, false)
	# Resume button is icon-only and should not have the button background on press
	# Resume button is icon-only and should not have the button background on press
	var flat_style = StyleBoxFlat.new()
	flat_style.bg_color = Color(0,0,0,0)

	var feedback_style = flat_style.duplicate()
	feedback_style.bg_color = Color(1, 1, 1, 0.2)
	feedback_style.set_corner_radius_all(20)

	resume_button.add_theme_stylebox_override("normal", flat_style)
	resume_button.add_theme_stylebox_override("hover", flat_style)
	resume_button.add_theme_stylebox_override("pressed", feedback_style)
	resume_button.add_theme_stylebox_override("focus", feedback_style)

	setup_credits_button()

func setup_credits_button() -> void:
	credits_button.pressed.connect(_on_credits_pressed)

	credits_button.text = "Credits"

func _on_credits_pressed() -> void:
	var credits_scene = preload("res://scenes/ui/credits.tscn").instantiate()
	add_child(credits_scene)


func _on_resume_pressed() -> void:
	GameManager.toggle_pause()

