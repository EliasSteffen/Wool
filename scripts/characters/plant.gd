class_name Plant
extends BaseEnemy

@export var fireball_scene: PackedScene

var _shoot_timer: float = 0.0
var _shoot_interval: float = 3.0
var _fireball_speed: float = 300.0

func _ready() -> void:
	super._ready()
	_setup_plant_tweakables()

	# Shoot immediately on start
	_shoot_timer = _shoot_interval

func _setup_plant_tweakables() -> void:
	_shoot_interval = CharacterConstants.get_value("Plant", "shoot_interval")
	_fireball_speed = CharacterConstants.get_value("Plant", "fireball_speed")

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	super._on_tweakable_changed(category, key, value)
	if category == "Plant":
		match key:
			"shoot_interval": _shoot_interval = float(value)
			"fireball_speed": _fireball_speed = float(value)

func _process(delta: float) -> void:
	# Debug timer progress
	# print("Plant Time: ", _shoot_timer)

	_shoot_timer += delta
	if _shoot_timer >= _shoot_interval:
		_shoot_timer = 0.0
		# print("Plant: Timer reached! stored scene: ", fireball_scene)
		shoot_fireball()

func shoot_fireball() -> void:
	if not fireball_scene:
		push_warning("Plant: No fireball_scene assigned!")
		return

	var fireball = fireball_scene.instantiate()

	# Add projectile to the main scene (usually /root/..., or the parent of behavior)
	get_parent().add_child(fireball)

	# Spawn relative to the plant's orientation
	# Local offset (0, -400) accounts for the plant height (since it's scaled down visuals, we assume local space of 1.0)
	# But wait, children are scaled 0.25, Root is 1.0.
	# If we want to spawn at the "mouth" (top of plant), that's near -200 to -250 in local unscaled space?
	# Plant visuals are 270px tall. Mouth is at top. So -270?
	# Let's say -250.
	var spawn_pos_local = Vector2(0, -250)
	fireball.global_position = to_global(spawn_pos_local)

	if "speed" in fireball:
		fireball.speed = _fireball_speed

	if "direction" in fireball:
		# Shoot in the direction the plant is facing (Up relative to plant)
		fireball.direction = Vector2.UP.rotated(global_rotation)

	# print("Plant: Shot fireball at ", fireball.global_position)

func _process_ai(_delta: float) -> void:
	# Override BaseEnemy AI to be static.
	velocity.x = 0
	velocity.y = 0
