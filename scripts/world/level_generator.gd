extends Node2D

@export var nail_scene: PackedScene = preload("res://scenes/interactions/nail.tscn")
@export var rusty_nail_scene: PackedScene = preload("res://scenes/interactions/rusty_nail.tscn")

## Vertical generation range
@export var gen_min_y: float = -1600.0
@export var gen_max_y: float = -150.0

const NAILS_PER_SEGMENT: int = 10

@onready var nails_container: Node = get_node_or_null("../Nails")

var _player: Node2D = null
var _camera_width: float = 0.0
var _last_generated_x: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
@export var minimal_nail_distance: float = 256.0
@export var nail_distance_increase_interval: float = 512.0
@export var nail_distance_increase_percent: float = 0.01
@export var max_min_nail_distance: float = 512.0
@export var rusty_nail_probability: float = 0.1
@export var rusty_nail_probability_increase_percent: float = 0.1
var _nails: Array[Node2D] = []

func _ready() -> void:
	# Initialize RNG with session seed from GameManager
	_rng.seed = GameManager.current_seed

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_camera_width = get_viewport().get_visible_rect().size.x

		# Initial spawn: 0 <= x <= camera_width
		_generate_nails_in_range(1024, _camera_width)

		# Spawn next segment: camera_width <= x <= 2*camera_width
		_generate_nails_in_range(_camera_width, 2.0 * _camera_width)
		_last_generated_x = 2.0 * _camera_width

func _process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player.camera:
		return

	var camera_left_border = _player.camera.global_position.x - (_camera_width / 2.0) / _player.camera.zoom.x

	# Generate ahead
	while _last_generated_x < camera_left_border + 2.0 * _camera_width:
		_generate_nails_in_range(_last_generated_x, _last_generated_x + _camera_width)
		_last_generated_x += _camera_width

	# Cleanup nails left from the camera
	_cleanup(camera_left_border - 100.0)

func _generate_nails_in_range(start_x: float, end_x: float) -> void:
	var steps: int = int(max(0.0, floor(start_x / nail_distance_increase_interval)))
	var current_min_distance: float = minimal_nail_distance * pow(1.0 + nail_distance_increase_percent, steps)
	if current_min_distance > max_min_nail_distance:
		current_min_distance = max_min_nail_distance
	var width = end_x - start_x
	var height = gen_max_y - gen_min_y
	var cells_x = ceil(width / current_min_distance)
	var cells_y = ceil(height / current_min_distance)

	for i in range(cells_x):
		for j in range(cells_y):
			var cell_x = start_x + i * current_min_distance
			var cell_y = gen_min_y + j * current_min_distance
			var x = _rng.randf_range(cell_x, min(cell_x + current_min_distance, end_x))
			var y = _rng.randf_range(cell_y, min(cell_y + current_min_distance, gen_max_y))
			var pos = Vector2(x, y)

			# Check distance to existing nails (from other segments)
			var ok: bool = true
			for nail in _nails:
				# Reject if too close (use <= to be conservative)
				if pos.distance_to(nail.global_position) <= current_min_distance:
					ok = false
					break

			if ok:
				var scene: PackedScene = nail_scene
				var current_rusty_probability: float = rusty_nail_probability + steps * rusty_nail_probability_increase_percent
				if _rng.randf() < current_rusty_probability:
					scene = rusty_nail_scene
				_spawn_nail(pos, scene)

func _spawn_nail(pos: Vector2, scene: PackedScene) -> void:
	var nail = scene.instantiate()
	if nails_container:
		nails_container.add_child(nail)
	else:
		add_child(nail)
	nail.global_position = pos
	_nails.append(nail)

func _cleanup(cleanup_x: float) -> void:
	var containers = []
	if nails_container:
		containers.append(nails_container)
	if get_child_count() > 0:
		containers.append(self)

	for container in containers:
		for child in container.get_children():
			if child is Node2D and child.global_position.x < cleanup_x:
				if not child.is_queued_for_deletion():
					_nails.erase(child)
					child.queue_free()
