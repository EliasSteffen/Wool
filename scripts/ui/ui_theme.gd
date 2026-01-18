# Utility helper for applying a modern, rounded button style across the UI
extends Node

class_name UITheme

static func apply_modern_button_style(button: Button, desired_size: Vector2 = Vector2.ZERO, icon_only: bool = false) -> void:
	if not is_instance_valid(button):
		return

	# Determine target height for sizing and corner radius
	var height: float = desired_size.y if desired_size.y > 0 else button.custom_minimum_size.y if button.custom_minimum_size.y > 0 else 80.0
	var radius: float = min(height * 0.5, 40.0)

	# Base style (normal)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.12, 1.0) # dark background
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	normal.corner_radius_top_left = radius
	normal.corner_radius_top_right = radius
	normal.corner_radius_bottom_left = radius
	normal.corner_radius_bottom_right = radius

	# Hover state
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.18, 0.18, 1.0)

	# Pressed / active state (accent color)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.08, 0.45, 0.9, 1.0) # modern accent blue

	# Apply styles
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)

	# Font and color
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", int(height * 0.35))

	# If icon-only button, make it square and fully round
	if icon_only:
		var s: float = desired_size.x if desired_size.x > 0 else max(button.custom_minimum_size.x, height)
		button.custom_minimum_size = Vector2(s, s)
		var r2: float = s * 0.5
		normal.corner_radius_top_left = r2
		normal.corner_radius_top_right = r2
		normal.corner_radius_bottom_left = r2
		normal.corner_radius_bottom_right = r2
		hover.corner_radius_top_left = r2
		hover.corner_radius_top_right = r2
		hover.corner_radius_bottom_left = r2
		hover.corner_radius_bottom_right = r2
		pressed.corner_radius_top_left = r2
		pressed.corner_radius_top_right = r2
		pressed.corner_radius_bottom_left = r2
		pressed.corner_radius_bottom_right = r2
		# Re-apply to update
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)

	# Make touch target comfortably large
	if button.custom_minimum_size.y < height:
		button.custom_minimum_size = Vector2(button.custom_minimum_size.x, height)

	# Slightly increase contrast for accessibility when focused
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	button.add_theme_constant_override("focus_outline_width", 0)
