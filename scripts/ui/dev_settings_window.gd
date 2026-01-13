extends CanvasLayer

@onready var container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
@onready var close_button: Button = $Panel/Header/CloseButton

func _ready() -> void:
	close_button.pressed.connect(close)

	# Make panel less transparent (more opaque)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95) # Dark grey, almost opaque
	$Panel.add_theme_stylebox_override("panel", style)

	_build_ui()

func _build_ui() -> void:
	# Clear existing
	for child in container.get_children():
		child.queue_free()

	# Add Export Button
	var export_btn = Button.new()
	export_btn.text = "Export Settings as JSON"
	export_btn.custom_minimum_size.y = 60 # Mobile touch target
	export_btn.pressed.connect(_on_export_pressed)
	container.add_child(export_btn)

	# Add separator
	container.add_child(HSeparator.new())

	# Build new from all registries
	for registry in Tweakables.registries:
		for category in registry.settings:
			_add_category_header(category)
			for key in registry.settings[category]:
				_add_setting_row(registry, category, key, registry.settings[category][key])

func _add_category_header(text: String) -> void:
	var label = Label.new()
	label.text = "--- " + text + " ---"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.YELLOW)
	container.add_child(label)

func _add_setting_row(registry: BaseConstants, category: String, key: String, data: Dictionary) -> void:
	var hbox = HBoxContainer.new()

	var label = Label.new()
	label.text = key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	var value = data["value"]
	var type = data.get("type", "")

	if type == "bool" or typeof(value) == TYPE_BOOL:
		var check = CheckBox.new()
		check.button_pressed = value
		check.custom_minimum_size = Vector2(60, 60) # Mobile touch target
		# Scale up the icon visual if possible, or just the container click area
		check.scale = Vector2(1.5, 1.5) # Slight visual scale
		check.toggled.connect(func(toggled):
			registry.set_value(category, key, toggled)
		)
		hbox.add_child(check)

	elif type == "color" or typeof(value) == TYPE_COLOR:
		var picker = ColorPickerButton.new()
		picker.color = value
		picker.custom_minimum_size = Vector2(80, 60) # Mobile touch target
		picker.color_changed.connect(func(col):
			registry.set_value(category, key, col)
		)
		hbox.add_child(picker)

	elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var slider = HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size.y = 60 # Touch height for slider
		slider.min_value = data.get("min", 0.0)
		slider.max_value = data.get("max", 1000.0)
		slider.step = data.get("step", 1.0)
		slider.value = value

		var spinbox = SpinBox.new()
		spinbox.min_value = data.get("min", 0.0)
		spinbox.max_value = data.get("max", 1000.0)
		spinbox.step = data.get("step", 1.0)
		spinbox.value = value
		spinbox.custom_minimum_size = Vector2(100, 60) # Larger spinbox

		# Sync Slider -> SpinBox & Registry
		slider.value_changed.connect(func(new_val):
			if spinbox.value != new_val:
				spinbox.value = new_val
			registry.set_value(category, key, new_val)
		)

		# Sync SpinBox -> Slider & Registry
		spinbox.value_changed.connect(func(new_val):
			if slider.value != new_val:
				slider.value = new_val
			registry.set_value(category, key, new_val)
		)

		hbox.add_child(slider)
		hbox.add_child(spinbox)

	container.add_child(hbox)

func open() -> void:
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	# Unpause if we are not in the PAUSED state (i.e. unpause for MENU and PLAYING)
	if GameManager.current_state != GameManager.GameState.PAUSED:
		get_tree().paused = false

func _on_export_pressed() -> void:
	var export_data: Dictionary = {}

	for registry in Tweakables.registries:
		# Merge settings from all registries
		# We assume categories are unique across registries
		for category in registry.settings:
			export_data[category] = registry.settings[category]

	var json_string = JSON.stringify(export_data, "\t")

	if OS.has_feature("web"):
		# Web export: Trigger download via JavaScript
		var buffer = json_string.to_utf8_buffer()
		JavaScriptBridge.download_buffer(buffer, "tweakables_export.json", "application/json")

		# Visual feedback
		var original_text = "Export Settings as JSON"
		var btn = container.get_child(0) as Button
		if btn:
			btn.text = "Downloaded!"
			await get_tree().create_timer(1.0).timeout
			btn.text = original_text
	else:
		# Desktop/Editor: Save to file
		var file_path = "res://tweakables_export.json"
		var file = FileAccess.open(file_path, FileAccess.WRITE)

		if file:
			file.store_string(json_string)
			file.close()
			print("Settings exported to: " + file_path)

			# Visual feedback
			var original_text = "Export Settings as JSON"
			var btn = container.get_child(0) as Button
			if btn:
				btn.text = "Saved!"
				await get_tree().create_timer(1.0).timeout
				btn.text = original_text
		else:
			push_error("Failed to save settings to " + file_path)
