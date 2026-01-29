class_name EnemySpawner
extends Node

# Config
# Config
var eagle_scene: PackedScene = preload("res://scenes/characters/enemies/eagle.tscn")
var fish_scene: PackedScene = preload("res://scenes/characters/enemies/fish.tscn")
var plant_scene: PackedScene = preload("res://scenes/characters/enemies/plant.tscn")

var spawn_distance_x: float = 2000.0 # Distance ahead of camera

# Eagle Config
var eagle_spawn_interval_min: float = 2.0
var eagle_spawn_interval_max: float = 5.0
var eagle_spawn_height_min: float = -200.0
var eagle_spawn_height_max: float = 0.0
var eagle_min_distance: int = 1000

# Fish Config
var fish_spawn_interval_min: float = 5.0
var fish_spawn_interval_max: float = 12.0
var fish_spawn_y: float = 0.0 # Approximate water level
var fish_min_distance: int = 500

# Plant Config
var plant_spawn_interval_min: float = 5.0
var plant_spawn_interval_max: float = 10.0
var plant_min_distance: int = 0
var plant_spawn_y: float = 0.0

var _eagle_timer: float = 0.0
var _fish_timer: float = 0.0
var _plant_timer: float = 0.0
var _player: Node2D = null
var _spawn_counts: Dictionary = {}

var _eagle_pool: ObjectPool
var _fish_pool: ObjectPool
var _plant_pool: ObjectPool

func _ready() -> void:
	_eagle_pool = ObjectPool.new(eagle_scene, get_parent(), 5)
	_fish_pool = ObjectPool.new(fish_scene, get_parent(), 5)
	_plant_pool = ObjectPool.new(plant_scene, get_parent(), 5)

	# Initialize Config from GameManager (safe to access here)
	eagle_spawn_height_max = GameManager.PLAYABLE_HEIGHT_TOP
	fish_spawn_y = GameManager.WATER_LEVEL
	plant_spawn_y = -128.0

	_reset_eagle_timer()
	_reset_fish_timer()
	_reset_plant_timer()

func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		return

	var current_dist = GameManager.get_current_distance()

	# Process Eagle Spawning
	_eagle_timer -= delta
	if _eagle_timer <= 0:
		if current_dist >= eagle_min_distance:
			_spawn_eagle()
			_reset_eagle_timer()
		else:
			_eagle_timer = 1.0

	# Process Fish Spawning
	_fish_timer -= delta
	if _fish_timer <= 0:
		if current_dist >= fish_min_distance:
			_spawn_fish()
			_reset_fish_timer()
		else:
			_fish_timer = 1.0

	# Process Plant Spawning
	_plant_timer -= delta
	if _plant_timer <= 0:
		if current_dist >= plant_min_distance:
			_spawn_plant()
			_reset_plant_timer()
		else:
			_plant_timer = 1.0

func _reset_eagle_timer() -> void:
	_eagle_timer = randf_range(eagle_spawn_interval_min, eagle_spawn_interval_max)

func _reset_fish_timer() -> void:
	_fish_timer = randf_range(fish_spawn_interval_min, fish_spawn_interval_max)

func _reset_plant_timer() -> void:
	_plant_timer = randf_range(plant_spawn_interval_min, plant_spawn_interval_max)

func _spawn_eagle() -> void:
	if not _player: return

	var spawn_x = _player.global_position.x + spawn_distance_x
	var spawn_y = randf_range(eagle_spawn_height_max, eagle_spawn_height_min)

	var eagle = _eagle_pool.acquire()
	if eagle.has_signal("despawn_requested"):
		if not eagle.despawn_requested.is_connected(_on_enemy_despawn_requested):
			eagle.despawn_requested.connect(_on_enemy_despawn_requested)

	eagle.global_position = Vector2(spawn_x, spawn_y)

	# Reset state?
	if eagle.has_method("reset"): eagle.reset()
	# Or manually reset velocity/etc if exposed.
	# Ideally add reset() to BaseEnemy

	_add_enemy(eagle, "Eagle")

func _spawn_fish() -> void:
	if not _player: return

	var spawn_x = _player.global_position.x + spawn_distance_x
	var spawn_y = fish_spawn_y

	var fish = _fish_pool.acquire()
	if fish.has_signal("despawn_requested"):
		if not fish.despawn_requested.is_connected(_on_enemy_despawn_requested):
			fish.despawn_requested.connect(_on_enemy_despawn_requested)

	fish.global_position = Vector2(spawn_x, spawn_y)
	if fish.has_method("reset"): fish.reset()

	print("DEBUG: Fish spawned at ", fish.global_position)
	_add_enemy(fish, "Fish")

func _spawn_plant() -> void:
	if not _player: return

	var spawn_x = _player.global_position.x + spawn_distance_x
	var spawn_y = plant_spawn_y

	var plant = _plant_pool.acquire()
	if plant.has_signal("despawn_requested"):
		if not plant.despawn_requested.is_connected(_on_enemy_despawn_requested):
			plant.despawn_requested.connect(_on_enemy_despawn_requested)

	plant.global_position = Vector2(spawn_x, spawn_y)
	if plant.has_method("reset"): plant.reset()

	_add_enemy(plant, "Plant")

func _add_enemy(enemy: Node, type_name: String) -> void:
	# No longer adding child here as pool handles it, but we might need to call ready?
	# ObjectPool adds child when creating. When acquiring, it just sets visible.

	# Initialize count for this type if not exists
	if not _spawn_counts.has(type_name):
		_spawn_counts[type_name] = 0

	# Apply warning to the first few enemies of this specific type
	_spawn_counts[type_name] += 1

	if enemy.has_method("show_spawn_warning"):
		enemy.call_deferred("show_spawn_warning")

func _on_enemy_despawn_requested(enemy: Node) -> void:
	# Determine which pool it belongs to based on type
	if enemy is Eagle:
		_eagle_pool.release(enemy)
	elif enemy is Fish:
		_fish_pool.release(enemy)
	elif enemy is Plant:
		_plant_pool.release(enemy)
