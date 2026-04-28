class_name GameOverScreen
extends Control

var _can_interact: bool = false

func _ready() -> void:
	# Connect close button from MenuBackground
	$MenuBackground/CloseButton.pressed.connect(_on_close_button_pressed)
	get_tree().root.size_changed.connect(_update_layout)
	call_deferred("_update_layout")

	# Start invisible
	modulate.a = 0.0

	var duration = 0.5 if Engine.time_scale != 1.0 else 1.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): _can_interact = true)

	_setup_score_display(duration)

@onready var score_display: Control = $MarginContainer/VBoxContainer/ScoreDisplay
@onready var menu_background: Control = $MenuBackground
@onready var content_margin: MarginContainer = $MarginContainer
# New References
@onready var highscore_container: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer
@onready var bar_mask: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/BarMask
@onready var platform_container: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/PlatformContainer
@onready var platform_sprite: Sprite2D = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/PlatformContainer/PlatformSprite
# Wool Marker is now a sibling of Platform Container
@onready var wool_marker: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/WoolMarker
@onready var wool_instance: Node = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/WoolMarker/Wool
@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/WoolMarker/ScoreLabel


@onready var end_label: Label = $MarginContainer/VBoxContainer/ScoreDisplay/EndLabel
@onready var new_highscore_label: Label = $MarginContainer/VBoxContainer/NewHighscoreLabel
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var instruction_label: Label = $MarginContainer/VBoxContainer/InstructionLabel

var _move_tween: Tween = null
var internal_wool_sprite: AnimatedSprite2D = null

func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var base_size: float = minf(viewport_size.x, viewport_size.y)
	var outer_margin_x: float = clampf(viewport_size.x * 0.08, 12.0, 150.0)
	var outer_margin_y: float = clampf(viewport_size.y * 0.08, 12.0, 150.0)
	var inner_margin_x: float = clampf(viewport_size.x * 0.06, 16.0, 90.0)
	var inner_margin_y: float = clampf(viewport_size.y * 0.06, 16.0, 90.0)

	menu_background.offset_left = outer_margin_x
	menu_background.offset_top = outer_margin_y
	menu_background.offset_right = -outer_margin_x
	menu_background.offset_bottom = -outer_margin_y

	# Keep text/content bound to the same panel rect as MenuBackground.
	content_margin.offset_left = outer_margin_x
	content_margin.offset_top = outer_margin_y
	content_margin.offset_right = -outer_margin_x
	content_margin.offset_bottom = -outer_margin_y

	content_margin.add_theme_constant_override("margin_left", int(inner_margin_x))
	content_margin.add_theme_constant_override("margin_top", int(inner_margin_y))
	content_margin.add_theme_constant_override("margin_right", int(inner_margin_x))
	content_margin.add_theme_constant_override("margin_bottom", int(inner_margin_y))

	title_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.1, 44.0, 150.0)))
	new_highscore_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.05, 24.0, 60.0)))
	end_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.035, 22.0, 40.0)))
	instruction_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.035, 22.0, 40.0)))
	score_label.add_theme_font_size_override("font_size", int(clampf(base_size * 0.03, 18.0, 32.0)))
	score_display.custom_minimum_size.y = clampf(viewport_size.y * 0.18, 120.0, 200.0)

func _setup_score_display(fade_duration: float) -> void:
	if not score_display: return

	var current_score = GameManager.max_run_distance

	# Save highscore (silently) if we beat it
	if current_score > GameManager.highscore:
		GameManager.update_highscore(current_score, true)

	var highscore = GameManager.highscore

	score_label.text = str(current_score) + "m"
	end_label.text = str(highscore) + "m"

	if GameManager.new_highscore_reached_this_run:
		if new_highscore_label: new_highscore_label.visible = true
		if score_label: score_label.visible = false

	# Setup Wool Instance
	if wool_instance:
		wool_instance.set_physics_process(false)
		wool_instance.set_process(false)
		if "can_control" in wool_instance: wool_instance.can_control = false
		if wool_instance.is_in_group("player"): wool_instance.remove_from_group("player")
		if wool_instance is CollisionObject2D:
			wool_instance.collision_layer = 0
			wool_instance.collision_mask = 0
		var cam = wool_instance.get_node_or_null("Camera2D")
		if cam: cam.queue_free()

		var skin = wool_instance.get_node_or_null("Skin")
		if skin: internal_wool_sprite = skin.get_node_or_null("AnimatedSprite2D")
		if internal_wool_sprite: internal_wool_sprite.play("idle")

	# Calculate ratio
	var ratio = 0.0
	if highscore > 0:
		ratio = float(current_score) / float(highscore)
	ratio = clampf(ratio, 0.0, 1.0)

	# Initial State
	bar_mask.size.x = 0
	platform_container.position.x = 0
	platform_sprite.rotation = 0
	platform_sprite.scale = Vector2(1, 1)
	wool_marker.position.x = 0 # Start at 0
	wool_marker.visible = false

	# Wait for layout
	var retries = 0
	while highscore_container.size.x <= 0 and retries < 10:
		await get_tree().process_frame
		retries += 1

	var total_width = highscore_container.size.x
	# Max width of the bar inside the mask should match container width
	if bar_mask.has_node("HighscoreBar"):
		var bar = bar_mask.get_node("HighscoreBar")
		bar.size.x = total_width # Stretch texture to full width

	# Platform moves ALL the way
	var platform_target_x = total_width

	# Wool stops at score
	var wool_target_x = total_width * ratio

	# Start Highscore Animation
	if GameManager.new_highscore_reached_this_run and new_highscore_label:
		new_highscore_label.pivot_offset = new_highscore_label.size / 2.0
		var pulse_tween = create_tween().set_loops()
		pulse_tween.tween_property(new_highscore_label, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(new_highscore_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Main Animation Sequence
	_move_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_move_tween.finished.connect(func():
		_move_tween = null
		_can_interact = true
	)
	_move_tween.tween_interval(fade_duration * 0.5)

	# 1. Platform moves FAST to the end
	var platform_duration = 1.2 # Fast
	_move_tween.tween_method(_animate_platform.bind(total_width), 0.0, 1.0, platform_duration).set_ease(Tween.EASE_OUT)

	# 2. Wool Waits
	_move_tween.tween_interval(0.2)

	var wool_limit = total_width * ratio

	# 3. Make wool visible and walk to score
	_move_tween.tween_callback(func():
		wool_marker.visible = true
		if internal_wool_sprite: internal_wool_sprite.play("walk")
	)

	# Duration proportional to distance
	var walk_duration = 2.0 * ratio
	if walk_duration < 1.0: walk_duration = 1.0

	_move_tween.tween_method(_animate_wool.bind(wool_limit, current_score), 0.0, 1.0, walk_duration).set_ease(Tween.EASE_OUT)

	# End
	_move_tween.tween_callback(func():
		if internal_wool_sprite: internal_wool_sprite.play("idle")
	)

func _animate_platform(t: float, total_width: float) -> void:
	# T goes 0->1
	var platform_x = total_width * t
	platform_container.position.x = platform_x
	bar_mask.size.x = platform_x

	# Rotate Platform
	var diameter = 100.0
	if platform_sprite and platform_sprite.texture:
		diameter = platform_sprite.texture.get_width() * platform_sprite.scale.x
	var rotations = platform_x / (PI * diameter)
	platform_sprite.rotation = rotations * TAU

	# Platform shrinks from 1.0 to 0.25
	var shrink_scale = lerp(1.0, 0.25, t)
	platform_sprite.scale = Vector2(shrink_scale, shrink_scale)

	# Disappear at very end
	if t >= 0.99:
		platform_sprite.visible = false
	else:
		platform_sprite.visible = true

func _animate_wool(t: float, max_x: float, max_score: int) -> void:
	# T goes 0->1
	var current_x = max_x * t
	wool_marker.position.x = current_x

	# Score
	var disp_score = int(float(max_score) * t)
	if score_label: score_label.text = str(disp_score) + "m"


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if (event is InputEventKey and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventJoypadButton and event.pressed):

		if _move_tween and _move_tween.is_valid():
			_move_tween.kill()
			_move_tween = null
			_skip_to_end()
			return

		if _can_interact:
			_restart_game()

func _skip_to_end() -> void:
	var current_score = GameManager.max_run_distance
	var highscore = max(GameManager.highscore, current_score)
	var ratio = 0.0
	if highscore > 0: ratio = float(current_score) / float(highscore)
	ratio = clampf(ratio, 0.0, 1.0)

	var total_width = highscore_container.size.x
	var wool_limit = total_width * ratio

	# End state
	_animate_platform(1.0, total_width)
	wool_marker.visible = true
	_animate_wool(1.0, wool_limit, current_score)

	if internal_wool_sprite: internal_wool_sprite.play("idle")

	_can_interact = true

func _restart_game() -> void:
	_can_interact = false
	Engine.time_scale = 1.0
	if get_parent() is CanvasLayer: get_parent().queue_free()
	else: queue_free()
	GameManager.start_game()

func _on_close_button_pressed() -> void:
	_restart_game()
