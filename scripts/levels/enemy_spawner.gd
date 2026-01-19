class_name EnemySpawner
extends Node

# Config
# Config
var eagle_scene: PackedScene = preload("res://scenes/characters/enemies/eagle.tscn")
var fish_scene: PackedScene = preload("res://scenes/characters/enemies/fish.tscn")

var spawn_distance_x: float = 2000.0 # Distance ahead of camera

# Eagle Config
var eagle_spawn_interval_min: float = 2.0
var eagle_spawn_interval_max: float = 5.0
var eagle_spawn_height_min: float = -200.0
var eagle_spawn_height_max: float = -400.0 
var eagle_min_distance: int = 1000

# Fish Config
var fish_spawn_interval_min: float = 5.0
var fish_spawn_interval_max: float = 12.0
var fish_spawn_y: float = 300.0 # Approximate water level
var fish_min_distance: int = 500

var _eagle_timer: float = 0.0
var _fish_timer: float = 0.0
var _player: Node2D = null
var _enemies_spawned_count: int = 0

func _ready() -> void:
	_reset_eagle_timer()
	_reset_fish_timer()

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

func _reset_eagle_timer() -> void:
	_eagle_timer = randf_range(eagle_spawn_interval_min, eagle_spawn_interval_max)

func _reset_fish_timer() -> void:
	_fish_timer = randf_range(fish_spawn_interval_min, fish_spawn_interval_max)

func _spawn_eagle() -> void:
	if not _player or not eagle_scene:
		return
		
	var spawn_x = _player.global_position.x + spawn_distance_x
	var spawn_y = _player.global_position.y + randf_range(eagle_spawn_height_max, eagle_spawn_height_min)
	
	var eagle = eagle_scene.instantiate()
	eagle.global_position = Vector2(spawn_x, spawn_y)
	
	_add_enemy(eagle)

func _spawn_fish() -> void:
	if not _player or not fish_scene:
		return
	
	var spawn_x = _player.global_position.x + spawn_distance_x
	var spawn_y = fish_spawn_y
	
	var fish = fish_scene.instantiate()
	fish.global_position = Vector2(spawn_x, spawn_y)
	print("DEBUG: Fish spawned at ", fish.global_position)
	
	_add_enemy(fish)

func _add_enemy(enemy: Node) -> void:
	get_parent().add_child.call_deferred(enemy)
	
	# Apply warning to the first few enemies regardless of type
	_enemies_spawned_count += 1
	if _enemies_spawned_count <= 3:
		if enemy.has_method("show_spawn_warning"):
			enemy.call_deferred("show_spawn_warning")
