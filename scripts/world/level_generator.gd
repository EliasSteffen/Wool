extends Node2D

@export var nail_scene: PackedScene = preload("res://scenes/interactions/nail.tscn")

@export var spawn_distance: float = 3000.0
@export var cleanup_distance: float = 2000.0
@export var chunk_width: float = 2000.0

## Vertical generation range
@export var gen_min_y: float = -3000.0
@export var gen_max_y: float = -250.0

@onready var nails_container: Node = get_node_or_null("../Nails")

var _player: Node2D = null
var _last_spawn_x: float = 0.0
var _last_nail_pos_high: Vector2 = Vector2.ZERO
var _last_nail_pos_mid: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	# Initialize RNG with session seed from GameManager
	_rng.seed = GameManager.current_seed
	print("LevelGenerator: Initialized with seed: ", _rng.seed)

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_last_spawn_x = _player.global_position.x + 300.0
		# Move initial nails MUCH closer (within reach)
		_last_nail_pos_high = _player.global_position + Vector2(200, -200)
		_last_nail_pos_mid = _player.global_position + Vector2(400, -100)
		
		# Spawn initial nails
		_spawn_nail(_last_nail_pos_high)
		_spawn_nail(_last_nail_pos_mid)
		_spawn_nail(_player.global_position + Vector2(600, -150))

var _cleanup_timer: float = 0.0
const CLEANUP_INTERVAL: float = 0.5

func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		return

	# Spawn ahead based on the furthest progress of either path
	var last_x = max(_last_nail_pos_high.x, _last_nail_pos_mid.x)
	if _player.global_position.x + spawn_distance > last_x:
		_generate_next_segment()

	# Cleanup staggered
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		_cleanup()

func _generate_next_segment() -> void:
	# Calculate path heights based on total range
	var height = abs(gen_max_y - gen_min_y)
	var segment = height / 3.0
	
	# High Path (top third)
	_last_nail_pos_high = _spawn_path_step(_last_nail_pos_high, gen_min_y, gen_min_y + segment)
	
	# Mid Path (middle third)
	_last_nail_pos_mid = _spawn_path_step(_last_nail_pos_mid, gen_min_y + segment, gen_min_y + 2 * segment)
	
	# Low Path (bottom third) - treated as a proper path now for full coverage
	# We use a temporary variable so we don't have to manage a third _last_nail_pos if not strictly needed for progress check,
	# but for consistency we just spawn directly in the range.
	var low_x = max(_last_nail_pos_high.x, _last_nail_pos_mid.x) + _rng.randf_range(50.0, 200.0)
	var low_y = _rng.randf_range(gen_min_y + 2 * segment, gen_max_y)
	_spawn_nail(Vector2(low_x, low_y))

func _spawn_path_step(last_pos: Vector2, min_y: float, max_y: float) -> Vector2:
	var x_offset = _rng.randf_range(250.0, 450.0) # Reduced from 400-600
	var y_offset = _rng.randf_range(-400.0, 400.0)
	
	var next_pos = last_pos + Vector2(x_offset, y_offset)
	next_pos.y = clamp(next_pos.y, min_y, max_y)
	
	_spawn_nail(next_pos)
	
	# High chance (75%) for extra nail - with tighter spacing
	if _rng.randf() > 0.25:
		var x_extra = _rng.randf_range(150.0, 300.0) # Reduced from 300-450
		if _rng.randf() > 0.5: x_extra *= -1
		
		var y_extra = _rng.randf_range(-300.0, 300.0)
		
		var extra_pos = next_pos + Vector2(x_extra, y_extra)
		extra_pos.y = clamp(extra_pos.y, min_y, max_y)
		
		# Ensure we don't spawn too close to ANY existing path point here
		if extra_pos.distance_to(next_pos) > 150.0: # Reduced from 300
			_spawn_nail(extra_pos)
		
	return next_pos

func _spawn_nail(pos: Vector2) -> void:
	var nail = nail_scene.instantiate()
	if nails_container:
		nails_container.add_child(nail)
	else:
		add_child(nail)
	nail.global_position = pos

func _cleanup() -> void:
	if not _player: return
	
	var cleanup_x = _player.global_position.x - cleanup_distance
	
	var containers = []
	if nails_container: containers.append(nails_container)
	if get_child_count() > 0: containers.append(self)
	
	for container in containers:
		for child in container.get_children():
			if child is Node2D and child.global_position.x < cleanup_x:
				# Use queue_free but with a small check to ensure it's not already exiting
				if not child.is_queued_for_deletion():
					child.queue_free()
