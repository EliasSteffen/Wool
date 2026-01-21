class_name Eagle
extends BaseEnemy

@export var fly_speed: float = 300.0

func _ready() -> void:
	super._ready()
	# Disable gravity for flying
	gravity = 0.0
	
	# Start flying left immediately
	velocity.x = -fly_speed
	
	# Initial direction update
	_update_direction()
	
	_setup_visibility_notifier()
	_setup_sound()

func reset() -> void:
	super.reset()
	velocity.x = -fly_speed
	velocity.y = 0.0
	_update_direction()

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
					# Centered rect based on texture size
					# Note: skin is scaled by BaseEnemy/Eagle scale, but notifier is child of Eagle (root).
					# Wait, notifier is child of Eagle. Eagle has scale 0.25.
					# Notifier is in local space of Eagle.
					# Skin is child of Eagle. Skin has scale (flipping).
					# Sprite is child of Skin.
					# We want the rect in Eagle's local space that covers the Sprite which is inside Scale.
					# If Sprite is 100x100. Eagle is 0.25.
					# In Eagle's local space, the sprite occupies 100x100 units (because Eagle's scale applies to children's rendering, but local coords are pre-scale).
					# So we just need the texture size.
					rect = Rect2(-size / 2.0, size)
	
	notifier.rect = rect
	add_child(notifier)
	
	# Only connect exit signal after we have entered the screen at least once.
	# This prevents immediate despawn since we spawn off-screen to the right.
	notifier.screen_entered.connect(func(): 
		# Once we enter the screen, we care about exiting it
		notifier.screen_exited.connect(func():
			despawn_requested.emit(self)
		)
		notifier.screen_exited.connect(func(): if _sfx_eagle: _sfx_eagle.stop())
		
		# Play Sound
		if _sfx_eagle: _sfx_eagle.play()
	)

var _sfx_eagle: AudioStreamPlayer2D

func _setup_sound() -> void:
	_sfx_eagle = AudioStreamPlayer2D.new()
	_sfx_eagle.stream = load("res://assets/sound/eagle.mp3")
	_sfx_eagle.bus = "SFX"
	_sfx_eagle.max_distance = 2000.0 # Ensure heard across screen
	add_child(_sfx_eagle)

func _process_ai(delta: float) -> void:
	# Maintain leftward velocity
	velocity.x = -fly_speed
	velocity.y = 0.0
	
	_update_direction()

func _stop_audio() -> void:
	if _sfx_eagle:
		_sfx_eagle.stop()

func _update_direction() -> void:
	# Always face left (direction of movement)
	if skin:
		# If velocity is negative (left), scale.x should be negative? 
		# It depends on the sprite. Usually positive scale = right facing.
		# If we fly left, we want to face left.
		# Assuming original sprite faces right.
		if skin.scale.x > 0:
			skin.scale.x = -abs(skin.scale.x)
