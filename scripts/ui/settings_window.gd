extends CanvasLayer

@onready var container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
@onready var close_button: Button = $Panel/CloseButton

func _ready() -> void:
	close_button.pressed.connect(close)

	# --- PAPER / CRAFT THEME ---

	# Main Panel: Paper Beige
	# Main Panel: Paper Texture Background
	var style = StyleBoxTexture.new()
	style.texture = load("res://assets/ui/settings-background.png")

	# Set margins essentially to 0 or appropriate values if the image has borders
	# Assuming full stretch as requested "scale it to fit"
	# We can keep content margins if needed for inner padding
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20

	# If the image shouldn't be tiled, we assume stretch (default axis stretch mode is STRETCH)
	# But StyleBoxTexture defaults to scaling to fit.

	$Panel.add_theme_stylebox_override("panel", style)

	# Apply modern rounded style to the close button (icon-like)
	var UITheme = preload("res://scripts/ui/ui_theme.gd")
	UITheme.apply_modern_button_style(close_button, Vector2(100, 100), true)

	# Update Close Button to use Light Gray Feedback instead of invisible
	var flat_style := StyleBoxFlat.new()
	flat_style.bg_color = Color(0,0,0,0)

	var feedback_style := flat_style.duplicate()
	feedback_style.bg_color = Color(0, 0, 0, 0.1) # Darker gray for paper theme contrast
	feedback_style.set_corner_radius_all(50) # Round

	close_button.add_theme_stylebox_override("normal", flat_style)
	close_button.add_theme_stylebox_override("hover", flat_style)
	close_button.add_theme_stylebox_override("pressed", feedback_style)
	close_button.add_theme_stylebox_override("focus", feedback_style)

	# Use asset icon for close (icon-only)
	close_button.text = ""
	var close_icon: Texture2D = preload("res://assets/ui/close-button.png")
	var close_icon_rect: TextureRect = close_button.get_node_or_null("IconTex") as TextureRect
	if not close_icon_rect:
		close_icon_rect = TextureRect.new()
		close_icon_rect.name = "IconTex"
		close_button.add_child(close_icon_rect)
		close_icon_rect.anchor_left = 0.0
		close_icon_rect.anchor_top = 0.0
		close_icon_rect.anchor_right = 1.0
		close_icon_rect.anchor_bottom = 1.0
		close_icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		close_icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		close_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	close_icon_rect.texture = close_icon

	# Enhance header visuals
	var header = $Panel.get_node_or_null("Header")
	if header:
		# Header Background: Transparent to show main background
		var header_style = StyleBoxFlat.new()
		header_style.bg_color = Color(0, 0, 0, 0) # Transparent
		header_style.content_margin_left = 16
		header_style.content_margin_right = 16
		header_style.content_margin_top = 12
		header_style.content_margin_bottom = 12
		header.add_theme_stylebox_override("panel", header_style)
		for child in header.get_children():
			if child is Label:
				# Header Text: Dark Ink
				child.add_theme_font_size_override("font_size", 40)
				child.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1)) # Dark Ink
				child.add_theme_color_override("font_shadow_color", Color(0,0,0,0)) # Remove shadow if any

	_build_ui()

	# Configure ScrollContainer for mobile scrolling
	var scroll_container = $Panel/ScrollContainer
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	# Add Safe Area Padding for notches (Landscape)
	$Panel.set_begin(Vector2(200, 75)) # offset_left and offset_top
	$Panel.set_end(Vector2(-200, -75)) # offset_right and offset_bottom

func _build_ui() -> void:
	# Clear existing
	for child in container.get_children():
		child.queue_free()

	# 1. Master Volume
	_add_volume_slider("Master Volume", "Master")

	# 2. Music Volume
	_add_volume_slider("Music Volume", "Music")

	# 3. SFX Volume
	_add_volume_slider("SFX Volume", "SFX")

func _add_volume_slider(label_text: String, bus_name: String) -> void:
	# Create a PanelContainer wrapper for each block
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	# Slider Row Background: Dark for high contrast against beige/bright background
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# Label
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95)) # Light color
	main_vbox.add_child(label)

	# Slider Row
	var slider_hbox = HBoxContainer.new()
	slider_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 100 # Larger touch area

	# Styles for Slider (Yarn-like)
	var slider_bg_style = StyleBoxFlat.new()
	slider_bg_style.bg_color = Color(0.85, 0.8, 0.75) # Cardboard/Dark Beige track
	slider_bg_style.expand_margin_top = 10
	slider_bg_style.expand_margin_bottom = 10
	slider_bg_style.corner_radius_top_left = 10
	slider_bg_style.corner_radius_top_right = 10
	slider_bg_style.corner_radius_bottom_left = 10
	slider_bg_style.corner_radius_bottom_right = 10

	var slider_fill_style = slider_bg_style.duplicate()
	slider_fill_style.bg_color = Color(0.4, 0.6, 0.8) # Soft Blue Yarn

	# Grabber (Knob) - needs to be handled via theme constants/icons usually, or just stylebox override for "grabber_area"
	# HSlider uses icons for grabber. We can mimic a "filled bar" style or just colored track.
	# "grabber_area" is the filled part to the left.

	slider.add_theme_stylebox_override("slider", slider_bg_style)
	slider.add_theme_stylebox_override("grabber_area", slider_fill_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_fill_style)

	# Audio Logic
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

	slider_hbox.add_child(slider)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 20
	slider_hbox.add_child(spacer)

	main_vbox.add_child(slider_hbox)
	container.add_child(panel)

func open() -> void:
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	# Unpause if we are not in the PAUSED state (i.e. unpause for MENU and PLAYING)
	if GameManager.current_state != GameManager.GameState.PAUSED:
		get_tree().paused = false

func _on_export_pressed() -> void:
	# Export feature removed/hidden as per previous simplification,
	# but keeping method if needed in future or just remove reference.
	pass
