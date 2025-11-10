class_name GrapplingNail
extends Node2D

# === SIGNALS ===
signal player_in_range(player: PlayerController)
signal player_out_of_range()

# === EXPORTED VARIABLES ===
@export var highlight_color: Color = Color(1.5, 1.5, 1.5, 1.0)
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)

# === PRIVATE VARIABLES ===
var _player_in_range: bool = false
var _is_connected: bool = false

# === ONREADY VARIABLES ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea

# === BUILT-IN METHODS ===
func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	sprite.modulate = normal_color
	print("Nail ready at position: ", global_position)

# === PUBLIC METHODS ===
func set_connected(connected: bool) -> void:
	_is_connected = connected

func is_player_in_range() -> bool:
	return _player_in_range

# === PRIVATE METHODS ===
func _update_highlight() -> void:
	if _player_in_range and not _is_connected:
		sprite.modulate = highlight_color
	else:
		sprite.modulate = normal_color

# === SIGNAL CALLBACKS ===
func _on_body_entered(body: Node2D) -> void:
	print("Body entered area: ", body.name, " Type: ", body.get_class())
	if body is PlayerController:
		print("Player detected! Highlighting nail.")
		_player_in_range = true
		_update_highlight()
		player_in_range.emit(self)  # Send the nail, not the player!

func _on_body_exited(body: Node2D) -> void:
	print("Body exited area: ", body.name)
	if body is PlayerController:
		print("Player left range.")
		_player_in_range = false
		_update_highlight()
		player_out_of_range.emit()
