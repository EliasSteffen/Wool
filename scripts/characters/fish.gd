class_name Fish
extends BaseEnemy

# Removed export var jump_strength
# Jump strength is now calculated dynamically

@export var horizontal_speed: float = -900.0

var _start_y: float = 0.0
var _start_x: float = 0.0

var _audio_player: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	_start_y = global_position.y
	_start_x = global_position.x

	_jump()
	_setup_visibility_notifier()
	_setup_audio()

func reset() -> void:
	super.reset()
	_start_y = global_position.y
	_start_x = global_position.x
	_jump()
	_start_audio()

func _setup_audio() -> void:
	if not _audio_player:
		_audio_player = AudioManager.create_audio_player(AudioManager.ENEMIES.FISH, self)
		if _audio_player:
			# VOLUME SET globally in AudioManager now (10%)
			_audio_player.finished.connect(_on_audio_finished)
			despawn_requested.connect(_on_despawn_requested)
			_start_audio()

func _start_audio() -> void:
	if _audio_player and not _audio_player.playing:
		_audio_player.play()

func _on_audio_finished() -> void:
	if _audio_player and is_inside_tree():
		_audio_player.play()

func _on_despawn_requested(_node: Node) -> void:
	if _audio_player:
		_audio_player.stop()

func _on_game_state_changed(new_state: int) -> void:
	super._on_game_state_changed(new_state)
	if new_state == GameManager.GameState.GAME_OVER:
		if _audio_player:
			_audio_player.stop()

func _setup_visibility_notifier() -> void:
	var notifier = VisibleOnScreenNotifier2D.new()

	# Dynamically calculate rect from sprite
	var rect = Rect2(-50, -50, 100, 100) # Fallback

	if skin and skin.has_node("AnimatedSprite2D"):
		var sprite = skin.get_node("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			var frames = sprite.sprite_frames
			if frames and frames.has_animation(sprite.animation):
				var texture = frames.get_frame_texture(sprite.animation, 0)
				if texture:
					var size = texture.get_size()
					rect = Rect2(-size / 2.0, size)

	notifier.rect = rect
	add_child(notifier)

	# notifier.screen_entered.connect(func():
	# 	AudioManager.play_sound(AudioManager.ENEMIES.SPUCKI)
	# )

	# Audio handling moved to BaseEnemy

func _process_ai(delta: float) -> void:
	# BaseCharacter applies gravity in _process_physics.
	# We just need to check if we fell back to water level.

	if velocity.y > 0 and global_position.y >= _start_y:
		# Fish has returned to the water -> Despawn
		despawn_requested.emit(self)
		set_physics_process(false)
		return

	# Rotate based on velocity to face movement direction
	rotation = velocity.angle() + PI

func _jump() -> void:
	# Recalculate or reuse jump velocity
	# Target significantly above the top of the playable area for a high jump
	var target_y = GameManager.PLAYABLE_HEIGHT_TOP - 1000.0
	var height_diff = _start_y - target_y

	if height_diff > 0:
		var jump_velocity = sqrt(2.0 * gravity * height_diff)
		velocity.y = -jump_velocity
		velocity.x = horizontal_speed # Apply lateral movement
		# Audio handled by visibility notifier
	else:
		velocity.y = -1000.0
		velocity.x = horizontal_speed
