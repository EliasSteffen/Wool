extends BaseMenu

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var dev_settings_button: Button = $CenterContainer/VBoxContainer/DevSettingsButton

func _ready() -> void:
	super._ready()
	# Ensure Main Menu always processes, even if game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	dev_settings_button.pressed.connect(_on_dev_settings_pressed)

	register_buttons([start_button, quit_button, dev_settings_button])

func _on_start_pressed() -> void:
	GameManager.start_game()

func _on_quit_pressed() -> void:
	GameManager.quit_game()

