extends CanvasLayer

@onready var container: VBoxContainer = $Control/OuterMargin/CenterContainer/Panel/ContentMargin/ScrollContainer/VBoxContainer
@onready var content_margin: MarginContainer = $Control/OuterMargin/CenterContainer/Panel/ContentMargin
@onready var scroll_container: ScrollContainer = $Control/OuterMargin/CenterContainer/Panel/ContentMargin/ScrollContainer
@onready var reset_button: Button = $Control/OuterMargin/CenterContainer/Panel/ContentMargin/ScrollContainer/VBoxContainer/ResetHighscoreButton
@onready var panel: Control = $Control/OuterMargin/CenterContainer/Panel

func _ready() -> void:
	var close_btn := get_node_or_null("Control/OuterMargin/CenterContainer/Panel/MenuBackground/CloseButton") as Button
	if close_btn:
		close_btn.pressed.connect(close)
	$Control.gui_input.connect(_on_overlay_gui_input)

	# Configure ScrollContainer for mobile scrolling
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	get_tree().root.size_changed.connect(_update_layout)
	call_deferred("_update_layout")

	# Find and setup sliders if they exist in the scene
	var master_slider = container.get_node_or_null("MasterVolume/VBoxContainer/HBoxContainer/HSlider")
	if master_slider: _setup_slider(master_slider, "Master")

	var music_slider = container.get_node_or_null("MusicVolume/VBoxContainer/HBoxContainer/HSlider")
	if music_slider: _setup_slider(music_slider, "Music")

	var sfx_slider = container.get_node_or_null("SFXVolume/VBoxContainer/HBoxContainer/HSlider")
	if sfx_slider: _setup_slider(sfx_slider, "SFX")

	var reset_btn := container.get_node_or_null("ResetHighscoreButton") as Button
	if reset_btn:
		reset_btn.pressed.connect(_on_reset_highscore_pressed)

func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if panel and not panel.get_global_rect().has_point(mb.position):
			close()
	elif event is InputEventScreenTouch and event.pressed:
		var st := event as InputEventScreenTouch
		if panel and not panel.get_global_rect().has_point(st.position):
			close()

func _update_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var base_size: float = min(viewport_size.x, viewport_size.y)
	var inner_margin_x := clampf(viewport_size.x * 0.05, 20.0, 160.0)
	var inner_margin_top := clampf(viewport_size.y * 0.05, 20.0, 80.0)
	var inner_margin_bottom := clampf(viewport_size.y * 0.04, 20.0, 40.0)
	var section_font_size := int(clampf(base_size * 0.055, 30.0, 80.0))
	var button_width := clampf(viewport_size.x * 0.55, 220.0, 800.0)
	var button_height := clampf(viewport_size.y * 0.12, 72.0, 150.0)
	var button_font_size := int(clampf(base_size * 0.055, 28.0, 80.0))

	content_margin.add_theme_constant_override("margin_left", int(inner_margin_x))
	content_margin.add_theme_constant_override("margin_top", int(inner_margin_top))
	content_margin.add_theme_constant_override("margin_right", int(inner_margin_x))
	content_margin.add_theme_constant_override("margin_bottom", int(inner_margin_bottom))
	container.add_theme_constant_override("separation", int(clampf(viewport_size.y * 0.03, 16.0, 40.0)))

	# ScrollContainer doesn't reliably shrink-wrap to children; give it a sane height derived from content.
	var content_min: Vector2 = container.get_combined_minimum_size()
	var desired_h: float = content_min.y + inner_margin_top + inner_margin_bottom
	var max_h: float = max(220.0, viewport_size.y - 300.0)
	scroll_container.custom_minimum_size.y = clampf(desired_h, 260.0, max_h)

	for label_path in [
		"MasterVolume/VBoxContainer/Label",
		"MusicVolume/VBoxContainer/Label",
		"SFXVolume/VBoxContainer/Label",
	]:
		var label := container.get_node_or_null(label_path) as Label
		if label:
			label.add_theme_font_size_override("font_size", section_font_size)

	reset_button.custom_minimum_size = Vector2(button_width, button_height)
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_button.add_theme_font_size_override("font_size", button_font_size)

func _on_reset_highscore_pressed() -> void:
	AudioManager.play_sound(AudioManager.GAME.CLICK)
	GameManager.reset_highscore()
	# Optional: feedback? For now just reset.

func _setup_slider(slider: HSlider, bus_name: String) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01

	# Initialize value from current db
	if bus_idx != -1:
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))

	slider.value_changed.connect(func(val):
		var b_idx = AudioServer.get_bus_index(bus_name)
		if b_idx != -1:
			AudioServer.set_bus_volume_db(b_idx, linear_to_db(val))
	)

func open() -> void:
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	# Unpause if we are not in the PAUSED state (i.e. unpause for MENU and PLAYING)
	if GameManager.current_state != GameManager.GameState.PAUSED:
		get_tree().paused = false
