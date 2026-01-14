extends Node2D

@export var nail_scene: PackedScene = preload("res://scenes/interactions/nail.tscn")
@export var platform_scene: PackedScene = preload("res://scenes/terrain/platform.tscn")

@export var spawn_distance: float = 3000.0
@export var cleanup_distance: float = 2000.0
@export var chunk_width: float = 2000.0

@onready var nails_container: Node = get_node_or_null("../Nails")
@onready var platforms_container: Node = get_node_or_null("../Platforms")

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
		_last_nail_pos_high = _player.global_position + Vector2(150, -250)
		_last_nail_pos_mid = _player.global_position + Vector2(200, -100)
		
		# Spawn initial nails for both paths
		_spawn_nail(_last_nail_pos_high)
		_spawn_nail(_last_nail_pos_mid)

func _process(_delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		return

	# Spawn ahead based on the furthest progress of either path
	var last_x = max(_last_nail_pos_high.x, _last_nail_pos_mid.x)
	if _player.global_position.x + spawn_distance > last_x:
		_generate_next_segment()

	# Cleanup behind
	_cleanup()

func _generate_next_segment() -> void:
	# High Path (near top border)
	_last_nail_pos_high = _spawn_path_step(_last_nail_pos_high, -2200.0, -1200.0)
	
	# Mid Path (central area)
	# Stagger Mid Path significantly from High Path
	var mid_base_x = _last_nail_pos_high.x - 400.0 # Staggered horizontally
	var next_mid_x = mid_base_x + _rng.randf_range(300.0, 500.0)
	var next_mid_y = clamp(_last_nail_pos_mid.y + _rng.randf_range(-300.0, 300.0), -1000.0, -400.0)
	
	_last_nail_pos_mid = Vector2(next_mid_x, next_mid_y)
	_spawn_nail(_last_nail_pos_mid)
	
	# Randomly spawn platforms at various heights
	if _rng.randf() > 0.5:
		var x_pos = max(_last_nail_pos_high.x, _last_nail_pos_mid.x)
		var platform_y = _rng.randf_range(-1200.0, -400.0)
		_spawn_platform(Vector2(x_pos + _rng.randf_range(-150, 150), platform_y))

func _spawn_path_step(last_pos: Vector2, min_y: float, max_y: float) -> Vector2:
	var x_offset = _rng.randf_range(400.0, 600.0)
	var y_offset = _rng.randf_range(-400.0, 400.0)
	
	var next_pos = last_pos + Vector2(x_offset, y_offset)
	next_pos.y = clamp(next_pos.y, min_y, max_y)
	
	_spawn_nail(next_pos)
	
	# High chance (50%) for extra nail - with even stricter spacing
	if _rng.randf() > 0.5:
		var x_extra = _rng.randf_range(300.0, 450.0) # Larger horizontal gap
		if _rng.randf() > 0.5: x_extra *= -1
		
		var y_extra = _rng.randf_range(-400.0, -200.0)
		if _rng.randf() > 0.7: y_extra *= -1
		
		var extra_pos = next_pos + Vector2(x_extra, y_extra)
		extra_pos.y = clamp(extra_pos.y, min_y, max_y)
		
		# Ensure we don't spawn too close to ANY existing path point here
		if extra_pos.distance_to(next_pos) > 300.0:
			_spawn_nail(extra_pos)
		
	return next_pos

func _spawn_nail(pos: Vector2) -> void:
	var nail = nail_scene.instantiate()
	if nails_container:
		nails_container.add_child(nail)
	else:
		add_child(nail)
	nail.global_position = pos

func _spawn_platform(pos: Vector2) -> void:
	var platform = platform_scene.instantiate()
	if platforms_container:
		platforms_container.add_child(platform)
	else:
		add_child(platform)
	
	platform.global_position = pos
	# Random scale
	var s = _rng.randf_range(0.5, 1.5)
	platform.scale = Vector2(s, s)

func _cleanup() -> void:
	var cleanup_x = _player.global_position.x - cleanup_distance
	
	var containers = [self]
	if nails_container: containers.append(nails_container)
	if platforms_container: containers.append(platforms_container)
	
	for container in containers:
		for child in container.get_children():
			if child is Node2D and child.global_position.x < cleanup_x:
				child.queue_free()
