class_name GameOverScreen
extends Control

var _can_interact: bool = false

func _ready() -> void:
	# Start invisible
	modulate.a = 0.0

	var duration = 0.5 if Engine.time_scale != 1.0 else 1.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): _can_interact = true)

	_setup_score_display(duration)

@onready var score_display: Control = $MarginContainer/VBoxContainer/ScoreDisplay
# New References
@onready var highscore_container: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer
@onready var bar_mask: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/BarMask
@onready var platform_container: Control = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/PlatformContainer
@onready var platform_sprite: Sprite2D = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/PlatformContainer/PlatformSprite
# Wool Marker is now a sibling of Platform Container
@onready var wool_marker: Node2D = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/WoolMarker
@onready var wool_instance: Node = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/WoolMarker/Wool
@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreDisplay/HighscoreContainer/WoolMarker/ScoreLabel


@onready var end_label: Label = $MarginContainer/VBoxContainer/ScoreDisplay/EndLabel
@onready var new_highscore_label: Label = $MarginContainer/VBoxContainer/NewHighscoreLabel

var _move_tween: Tween = null
var internal_wool_sprite: AnimatedSprite2D = null

func _setup_score_display(fade_duration: float) -> void:
	if not score_display: return

	var current_score = GameManager.max_run_distance
	var highscore = max(GameManager.highscore, current_score)

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

	# Main Animation
	_move_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	# Using Linear for speed matching? No, usually ease-out looks better.
	# If I use ease-out for both, and same duration, they will desync if distances differ (which they do).
	# To keep them "together" initially, they must have same SPEED profile.

	# Platform Duration = Base Duration (e.g. 2.0s)
	# Wool Duration = Base Duration * (wool_target / platform_target) = Base * ratio?
	# IF we use Linear.
	# If we use Quad ease-out, speed varies over time. Syncing two different distance tweens is hard.

	# Alternative: Tween a "progress" value from 0.0 to 1.0
	# Then manually set positions in `tween_method` or `_process`.

	_move_tween.finished.connect(func():
		_move_tween = null
		_can_interact = true
	)
	_move_tween.tween_interval(fade_duration * 0.5)

	# Start Walk
	_move_tween.tween_callback(func():
		if internal_wool_sprite: internal_wool_sprite.play("walk")
	)

	# We will tween a generic float 't' from 0.0 to 1.0
	_move_tween.tween_method(_animate_progress.bind(total_width, ratio), 0.0, 1.0, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# End
	_move_tween.tween_callback(func():
		if internal_wool_sprite: internal_wool_sprite.play("idle")
	)

func _animate_progress(t: float, total_width: float, score_ratio: float) -> void:
	# T goes 0->1

	# Platform moves full width based on T
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

	# "then let him dissappear" -> at the very end
	if t >= 0.99:
		platform_sprite.visible = false
	else:
		platform_sprite.visible = true

	# Wool moves with platform untill it reaches limit
	# Wool limit = total_width * score_ratio
	# Wool follows platform position, clamped to limit.
	var wool_limit = total_width * score_ratio
	var wool_x = min(platform_x, wool_limit)
	wool_marker.position.x = wool_x

	# Update Score Text
	# Score is proportional to WOOL position, not T
	var current_score_val = int((wool_x / total_width) * float(GameManager.highscore)) # Approximate?
	# Better: map wool_x back to score
	# wool_x / wool_limit = fraction of score? No.
	# wool_limit matches current_score.
	# So fraction = wool_x / (total_width * ratio) * current_score?
	# = wool_x / wool_limit * current_score.

	var disp_score = 0
	if wool_limit > 0.001:
		disp_score = int((wool_x / wool_limit) * float(GameManager.max_run_distance))

	if score_label: score_label.text = str(disp_score) + "m"

	# Handle Wool Animation state
	if internal_wool_sprite:
		if wool_x >= wool_limit and t < 1.0 and score_ratio < 1.0:
			# Wool stopped moving but platform continues
			if internal_wool_sprite.animation != "idle":
				internal_wool_sprite.play("idle")
		else:
			if internal_wool_sprite.animation != "walk":
				internal_wool_sprite.play("walk")


func _input(event: InputEvent) -> void:
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

	# End state
	_animate_progress(1.0, total_width, ratio)

	_can_interact = true

func _restart_game() -> void:
	_can_interact = false
	Engine.time_scale = 1.0
	if get_parent() is CanvasLayer: get_parent().queue_free()
	else: queue_free()
	GameManager.start_game()
