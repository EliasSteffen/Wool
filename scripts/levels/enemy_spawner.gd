class_name EnemySpawner
extends Node

# Config
var eagle_scene: PackedScene = preload("res://scenes/characters/enemies/eagle.tscn")
var spawn_interval_min: float = 2.0
var spawn_interval_max: float = 5.0
var spawn_distance_x: float = 2000.0 # Distance ahead of camera
var spawn_height_min: float = -200.0 # Relative to camera center or fixed? User said "certain height"
var spawn_height_max: float = -400.0 

var _spawn_timer: float = 0.0
var _player: Node2D = null
var _enemies_spawned_count: int = 0

func _ready() -> void:
	_reset_timer()

func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0:
		if GameManager.get_current_distance() >= 0:
			_spawn_eagle()
			_reset_timer()
		else:
			# Not far enough yet, wait a bit
			_spawn_timer = 1.0 # Check every second until requirement met

func _reset_timer() -> void:
	_spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)

func _spawn_eagle() -> void:
	if not _player or not eagle_scene:
		return
		
	# Spawn relative to player/camera
	# Assuming player is the reference point for forward progression
	
	var spawn_x = _player.global_position.x + spawn_distance_x
	
	# Spawn height relative to player? Or absolute?
	# "Spawn randomly on a certain height" - likely implies a variation around a fixed altitude or relative to player
	var spawn_y = _player.global_position.y + randf_range(spawn_height_max, spawn_height_min)
	
	var eagle = eagle_scene.instantiate()
	eagle.global_position = Vector2(spawn_x, spawn_y)
	
	# Add to scene
	# We want to add it to the same container as enemies or just the main level
	# get_parent() assumes this script is attached to Level
	get_parent().add_child.call_deferred(eagle)
	
	_enemies_spawned_count += 1
	if _enemies_spawned_count <= 3:
		eagle.call_deferred("show_spawn_warning")
