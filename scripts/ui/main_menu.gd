extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var dev_settings_button: Button = $CenterContainer/VBoxContainer/DevSettingsButton

const DEV_SETTINGS_SCENE = preload("res://scenes/ui/dev_settings_window.tscn")
var _dev_settings_instance: Node = null

func _ready() -> void:
	# Ensure Main Menu always processes, even if game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	dev_settings_button.pressed.connect(_on_dev_settings_pressed)

func _on_start_pressed() -> void:
	GameManager.start_game()

func _on_quit_pressed() -> void:
	GameManager.quit_game()

func _on_dev_settings_pressed() -> void:
	if not _dev_settings_instance:
		_dev_settings_instance = DEV_SETTINGS_SCENE.instantiate()
		get_tree().root.add_child(_dev_settings_instance)

	if _dev_settings_instance.has_method("open"):
		_dev_settings_instance.open()
	else:
		_dev_settings_instance.show()

