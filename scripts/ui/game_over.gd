class_name GameOverScreen
extends Control

var _can_interact: bool = false

func _ready() -> void:
	# Start invisible
	modulate.a = 0.0

	# Fade in over 1 second (adjusted for time_scale in BasePlayer)
	# If time_scale is 0.5, 0.5s duration = 1.0s real time
	var duration = 0.5 if Engine.time_scale != 1.0 else 1.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): _can_interact = true)

	_setup_score_display(duration)

@onready var score_display: Control = $MarginContainer/VBoxContainer/ScoreDisplay
@onready var progress_container: Control = $MarginContainer/VBoxContainer/ScoreDisplay/ProgressBarContainer
@onready var line_base: Panel = $MarginContainer/VBoxContainer/ScoreDisplay/ProgressBarContainer/LineBase
@onready var line_fill: Panel = $MarginContainer/VBoxContainer/ScoreDisplay/ProgressBarContainer/LineFill
@onready var wool_marker: Control = $MarginContainer/VBoxContainer/ScoreDisplay/ProgressBarContainer/WoolMarker
@onready var wool_instance: Node = $MarginContainer/VBoxContainer/ScoreDisplay/ProgressBarContainer/WoolMarker/Wool
@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreDisplay/ProgressBarContainer/WoolMarker/ScoreLabel
@onready var end_label: Label = $MarginContainer/VBoxContainer/ScoreDisplay/EndLabel

var internal_wool_sprite: AnimatedSprite2D = null

func _setup_score_display(fade_duration: float) -> void:
	if not score_display:
		return
	
	_setup_styles()
		
	var current_score = GameManager.max_run_distance
	var highscore = max(GameManager.highscore, current_score) # Ensure highscore is at least current score
	
	score_label.text = str(current_score) + "m"
	end_label.text = str(highscore) + "m"
	
	# Setup Wool Instance
	if wool_instance:
		# Disable physics and game logic for this UI instance
		wool_instance.set_physics_process(false)
		wool_instance.set_process(false)
		if "can_control" in wool_instance:
			wool_instance.can_control = false

		# Neuter the instance (Prevent interaction with world)
		if wool_instance.is_in_group("player"):
			wool_instance.remove_from_group("player")
		
		# Disable Collisions
		if wool_instance is CollisionObject2D:
			wool_instance.collision_layer = 0
			wool_instance.collision_mask = 0
			
		# Remove Camera (Prevent stealing focus)
		var cam = wool_instance.get_node_or_null("Camera2D")
		if cam:
			cam.queue_free()
		
		# Find the internal AnimatedSprite2D to animate it
		var skin = wool_instance.get_node_or_null("Skin")
		if skin:
			internal_wool_sprite = skin.get_node_or_null("AnimatedSprite2D")
			
		if internal_wool_sprite:
			internal_wool_sprite.play("idle")
	
	# Calculate ratio (0.0 to 1.0)
	var ratio = 0.0
	if highscore > 0:
		ratio = float(current_score) / float(highscore)
	
	# Clamp ratio just in case
	ratio = clampf(ratio, 0.0, 1.0)
	
	# Initial State
	wool_marker.position.x = 0
	line_fill.size.x = 0
	
	# Wait for layout to determine width
	# We loop a few times to ensure layout has propagated
	var retries = 0
	while progress_container.size.x <= 0 and retries < 10:
		await get_tree().process_frame
		retries += 1
	
	var total_width = progress_container.size.x
	var target_x = total_width * ratio
	
	print("Game Over Debug: Score=", current_score, " MaxWidth=", total_width, " TargetX=", target_x, " Ratio=", ratio)
	
	if total_width <= 0:
		printerr("Game Over Error: ProgressBar width is 0!")
	
	if not internal_wool_sprite:
		printerr("Game Over Error: Internal Wool Sprite not found on instance!")
	
	# Animation
	var move_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Start moving after start delay
	move_tween.tween_interval(fade_duration * 0.5)
	
	# Start Walk Animation callback
	move_tween.tween_callback(func():
		if internal_wool_sprite:
			internal_wool_sprite.play("walk")
	)
	
	# Parallel movement, fill, and text counting
	move_tween.set_parallel(true)
	move_tween.tween_property(wool_marker, "position:x", target_x, 2.0)
	move_tween.tween_property(line_fill, "size:x", target_x, 2.0)
	# Animate the score counting up
	move_tween.tween_method(_update_score_text, 0, current_score, 2.0)
	move_tween.set_parallel(false)
	
	# End callback
	move_tween.tween_callback(func():
		if internal_wool_sprite:
			internal_wool_sprite.play("idle")
	)

func _update_score_text(value: int) -> void:
	if score_label:
		score_label.text = str(value) + "m"


func _input(event: InputEvent) -> void:
	if not _can_interact:
		return

	if (event is InputEventKey and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventJoypadButton and event.pressed):
		_restart_game()

func _restart_game() -> void:
	# Prevent double firing
	_can_interact = false
	# Reset time scale
	Engine.time_scale = 1.0

	# Clean up the overlay (CanvasLayer)
	if get_parent() is CanvasLayer:
		get_parent().queue_free()
	else:
		queue_free()

	# Restart the level
	GameManager.start_game()

func _setup_styles() -> void:
	# Configure Rounded Corners (10px radius for 20px height)
	var radius = 10
	
	# Line Base (Background)
	if line_base:
		var style_base = StyleBoxFlat.new()
		style_base.bg_color = Color(1, 1, 1, 0.3)
		style_base.set_corner_radius_all(radius)
		line_base.add_theme_stylebox_override("panel", style_base)
		
	# Line Fill (Foreground)
	if line_fill:
		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = Color(1, 1, 1, 1) # Solid White
		style_fill.set_corner_radius_all(radius)
		line_fill.add_theme_stylebox_override("panel", style_fill)
