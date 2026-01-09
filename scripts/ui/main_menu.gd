extends BaseMenu

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var dev_settings_button: Button = $CenterContainer/VBoxContainer/DevSettingsButton

# Level Selection UI
@onready var main_container: Container = $CenterContainer
@onready var level_selection: Control = $LevelSelection
@onready var level_container: HBoxContainer = $LevelSelection/ScrollContainer/HBoxContainer
@onready var back_button: Button = $LevelSelection/BackButton

# Level Data
var levels: Array = [
	{
		"name": "Level 1: The Beginning",
		"scene": "res://scenes/levels/level_1.tscn",
		"preview": "res://assets/maps/background.svg"
	},
	{
		"name": "Level 2: The Cave",
		"scene": "res://scenes/levels/level_2.tscn",
		"preview": "res://assets/maps/background.svg"
	}
]

func _ready() -> void:
	super._ready()
	# Ensure Main Menu always processes, even if game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	dev_settings_button.pressed.connect(_on_dev_settings_pressed)
	back_button.pressed.connect(_on_back_pressed)

	register_buttons([start_button, quit_button, dev_settings_button, back_button])

	_populate_level_list()

func _populate_level_list() -> void:
	# Clear existing children
	for child in level_container.get_children():
		child.queue_free()

	for level_data in levels:
		var btn = _create_level_button(level_data)
		level_container.add_child(btn)

func _create_level_button(data: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(300, 300)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var vbox = VBoxContainer.new()
	vbox.layout_mode = 1 # Anchors Layout
	vbox.anchors_preset = 15 # Full Rect
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let click pass to button
	button.add_child(vbox)

	# Preview Image
	var texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ResourceLoader.exists(data.preview):
		texture_rect.texture = load(data.preview)
	else:
		texture_rect.modulate = Color(0.2, 0.2, 0.2) # Gray placeholder

	vbox.add_child(texture_rect)

	# Label
	var label = Label.new()
	label.text = data.name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 50)
	label.theme_type_variation = "HeaderMedium"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)

	# Connect
	button.pressed.connect(func(): _load_level(data.scene))

	return button

func _on_start_pressed() -> void:
	# Show level selection instead of direct start
	main_container.visible = false
	level_selection.visible = true

func _on_back_pressed() -> void:
	main_container.visible = true
	level_selection.visible = false

func _load_level(scene_path: String) -> void:
	# Use GameManager to load properly
	# We can't call GameManager.load_level yet if it doesn't exist, so hack for now:
	GameManager.current_state = GameManager.GameState.PLAYING
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
	GameManager.state_changed.emit(GameManager.current_state)

func _on_quit_pressed() -> void:
	GameManager.quit_game()
