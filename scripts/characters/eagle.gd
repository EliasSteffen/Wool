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

func _setup_visibility_notifier() -> void:
	var notifier = VisibleOnScreenNotifier2D.new()
	# Set a rect that covers the bird (approximate size based on sprite/shape)
	# Shape was ~1300x560 scaled by 0.5 -> ~650x280
	notifier.rect = Rect2(-350, -150, 700, 300)
	add_child(notifier)
	
	# Only connect exit signal after we have entered the screen at least once.
	# This prevents immediate despawn since we spawn off-screen to the right.
	notifier.screen_entered.connect(func(): 
		# Once we enter the screen, we care about exiting it
		notifier.screen_exited.connect(queue_free)
	)

func _process_ai(delta: float) -> void:
	# Maintain leftward velocity
	velocity.x = -fly_speed
	velocity.y = 0.0
	
	_update_direction()

func _update_direction() -> void:
	# Always face left (direction of movement)
	if skin:
		# If velocity is negative (left), scale.x should be negative? 
		# It depends on the sprite. Usually positive scale = right facing.
		# If we fly left, we want to face left.
		# Assuming original sprite faces right.
		if skin.scale.x > 0:
			skin.scale.x = -abs(skin.scale.x)
