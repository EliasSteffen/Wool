extends BaseMenu

@onready var settings_button: Button = $Control/OuterMargin/CenterContainer/MenuPanel/Content/VBoxContainer/SettingsButton
@onready var credits_button: Button = $Control/OuterMargin/CenterContainer/MenuPanel/Content/VBoxContainer/CreditsButton
@onready var menu_panel: Control = $Control/OuterMargin/CenterContainer/MenuPanel
@onready var pause_close_button: Button = $Control/OuterMargin/CenterContainer/MenuPanel/MenuBackground/CloseButton

var _credits_instance: Node = null

func _ready() -> void:
	super._ready()
	pause_close_button.pressed.connect(_on_resume_pressed)
	$Control.gui_input.connect(_on_overlay_gui_input)
	settings_button.pressed.connect(_on_settings_pressed)

	# Buttons will use the textured theme from assets/ui/pause_theme.tres

	settings_button.text = "Settings"

	register_buttons([settings_button, credits_button], false, true)

	credits_button.pressed.connect(_on_credits_pressed)

	credits_button.text = "Credits"

func _on_overlay_gui_input(event: InputEvent) -> void:
	if _credits_instance and is_instance_valid(_credits_instance):
		return

	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if menu_panel and not menu_panel.get_global_rect().has_point(mb.position):
			_on_resume_pressed()
	elif event is InputEventScreenTouch and event.pressed:
		var st := event as InputEventScreenTouch
		if menu_panel and not menu_panel.get_global_rect().has_point(st.position):
			_on_resume_pressed()

func _on_credits_pressed() -> void:
	if _credits_instance and is_instance_valid(_credits_instance):
		return

	AudioManager.play_sound(AudioManager.GAME.CLICK)
	_credits_instance = preload("res://scenes/ui/credits.tscn").instantiate()
	pause_close_button.visible = false
	add_child(_credits_instance)
	if _credits_instance.has_signal("closed"):
		_credits_instance.closed.connect(_on_credits_closed)
	_credits_instance.tree_exited.connect(_on_credits_closed)

func _on_credits_closed() -> void:
	if pause_close_button:
		pause_close_button.visible = true
	_credits_instance = null


func _on_resume_pressed() -> void:
	GameManager.toggle_pause()
