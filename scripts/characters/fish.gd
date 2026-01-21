class_name Fish
extends BaseEnemy

# Removed export var jump_strength
# Jump strength is now calculated dynamically

@export var horizontal_speed: float = -900.0

var _start_y: float = 0.0
var _start_x: float = 0.0

func _ready() -> void:
	super._ready()
	_start_y = global_position.y
	_start_x = global_position.x
	
	_jump()
	_setup_sound()
	_setup_visibility_notifier()

func reset() -> void:
	super.reset()
	_start_y = global_position.y # Will be set after position update? No, position set before reset call usually? 
	# Actually spawner sets position AFTER acquiring but BEFORE reset?
	# In my spawner code: acquire -> set signal -> set position -> reset.
	# So global_position is correct here.
	_start_y = global_position.y
	_start_x = global_position.x
	_jump()

var _sfx_fish: AudioStreamPlayer2D

func _setup_sound() -> void:
	_sfx_fish = AudioStreamPlayer2D.new()
	_sfx_fish.stream = load("res://assets/sound/fish.mp3")
	_sfx_fish.bus = "SFX"
	_sfx_fish.max_distance = 1500.0
	add_child(_sfx_fish)

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
	
	notifier.screen_entered.connect(func():
		if _sfx_fish: _sfx_fish.play()
	)
	notifier.screen_exited.connect(func():
		if _sfx_fish: _sfx_fish.stop()
	)

func _process_ai(delta: float) -> void:
	# BaseCharacter applies gravity in _process_physics.
	# We just need to check if we fell back to water level.
	
	if velocity.y > 0 and global_position.y >= _start_y:
		# Fish has returned to the water -> Despawn
		despawn_requested.emit(self)

func _stop_audio() -> void:
	if _sfx_fish:
		_sfx_fish.stop()
func _jump() -> void:
	# Recalculate or reuse jump velocity
	# Target significantly above the top of the playable area for a high jump
	var target_y = GameManager.PLAYABLE_HEIGHT_TOP - 400.0
	var height_diff = _start_y - target_y
	
	if height_diff > 0:
		var jump_velocity = sqrt(2.0 * gravity * height_diff)
		velocity.y = -jump_velocity
		velocity.x = horizontal_speed # Apply lateral movement
		print("DEBUG: Fish jumping with velocity ", velocity)
	else:
		velocity.y = -1000.0
		velocity.x = horizontal_speed
