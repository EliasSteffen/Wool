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

	# Buttons will use the textured theme from assets/ui/pause_theme.tres
	resume_button.text = "Resume"
	reset_button.text = "Reset Highscore"
	settings_button.text = "Settings"

	register_buttons([resume_button, reset_button, settings_button, credits_button], false, false)

	setup_credits_button()

func setup_credits_button() -> void:
	credits_button.pressed.connect(_on_credits_pressed)

	credits_button.text = "Credits"

func _on_credits_pressed() -> void:
	var credits_scene = preload("res://scenes/ui/credits.tscn").instantiate()
	add_child(credits_scene)


func _on_resume_pressed() -> void:
	GameManager.toggle_pause()

func _on_reset_highscore_pressed() -> void:
	GameManager.reset_highscore()
	reset_button.text = "Highscore Reset!"
	reset_button.disabled = true

	await get_tree().create_timer(1.5).timeout

	reset_button.text = "Reset Highscore"
	reset_button.disabled = false
