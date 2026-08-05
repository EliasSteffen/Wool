extends CanvasLayer

## Emitted when the user dismisses this window. UIManager listens and does the
## actual closing - see the "windows never close themselves" rule in ui_manager.gd.
signal close_requested

@onready var container: VBoxContainer = $Control/OuterMargin/CenterContainer/Panel/ContentMargin/ScrollContainer/VBoxContainer
@onready var content_margin: MarginContainer = $Control/OuterMargin/CenterContainer/Panel/ContentMargin
@onready var scroll_container: ScrollContainer = $Control/OuterMargin/CenterContainer/Panel/ContentMargin/ScrollContainer
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

	_setup_name_edit()

func _setup_name_edit() -> void:
	var name_edit := container.get_node_or_null("PlayerName/VBoxContainer/NameEdit") as LineEdit
	if not name_edit:
		return

	name_edit.text = LeaderboardManager.player_name
	# Commit on Enter and on losing focus, so the value is never lost to a
	# tap-outside close.
	name_edit.text_submitted.connect(func(_new_text: String): _commit_name(name_edit))
	name_edit.focus_exited.connect(func(): _commit_name(name_edit))
	name_edit.text_changed.connect(func(_new_text: String): _set_name_status(false))

func _commit_name(name_edit: LineEdit) -> void:
	var entered: String = LeaderboardEntry.sanitize_name(name_edit.text)

	# Empty or unchanged - nothing to do, just restore what is stored.
	if entered.is_empty() or entered == LeaderboardManager.player_name:
		name_edit.text = LeaderboardManager.player_name
		_set_name_status(false)
		return

	name_edit.editable = false
	var available: bool = await LeaderboardManager.is_name_available(entered)
	if not is_instance_valid(name_edit):
		return
	name_edit.editable = true

	if not available:
		# Put the old name back so the field never shows a name they do not own.
		name_edit.text = LeaderboardManager.player_name
		_set_name_status(true)
		return

	_set_name_status(false)
	LeaderboardManager.set_player_name(entered)

func _set_name_status(is_taken: bool) -> void:
	var status := container.get_node_or_null("PlayerName/VBoxContainer/NameStatusLabel") as Label
	if status:
		status.visible = is_taken

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

	var name_edit := container.get_node_or_null("PlayerName/VBoxContainer/NameEdit") as LineEdit
	if name_edit:
		name_edit.add_theme_font_size_override("font_size", int(clampf(base_size * 0.035, 22.0, 44.0)))
		# Width only - the styled box brings its own vertical padding.
		name_edit.custom_minimum_size = Vector2(clampf(viewport_size.x * 0.3, 240.0, 480.0), 0.0)

	for label_path in [
		"MasterVolume/VBoxContainer/Label",
		"MusicVolume/VBoxContainer/Label",
		"SFXVolume/VBoxContainer/Label",
		"PlayerName/VBoxContainer/Label",
	]:
		var label := container.get_node_or_null(label_path) as Label
		if label:
			label.add_theme_font_size_override("font_size", section_font_size)

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

## Asks UIManager to close this window. Nothing here hides itself or touches
## get_tree().paused - the manager owns both.
func close() -> void:
	close_requested.emit()

## The name field commits on focus_exited; hiding a CanvasLayer does not drop
## focus, so a name typed and then dismissed by tap-outside would be lost.
func on_closed() -> void:
	var name_edit := container.get_node_or_null("PlayerName/VBoxContainer/NameEdit") as LineEdit
	if name_edit and name_edit.has_focus():
		name_edit.release_focus()
