class_name Wool
extends BasePlayer

# === ONREADY VARIABLES ===
# Physics Shapes
@onready var physics_shape_default: CollisionShape2D = $PhysicsShape
@onready var physics_shape_double_jump: CollisionShape2D = $PhysicsShape_DoubleJump
@onready var physics_shape_glide: CollisionShape2D = $PhysicsShape_Glide
@onready var physics_shape_swim: CollisionShape2D = $PhysicsShape_Swim
@onready var physics_shape_wings: CollisionShape2D = $PhysicsShape_Wings

# Hitbox Shapes
@onready var hitbox_shape_default: CollisionShape2D = $HitboxArea/HitboxShape
@onready var hitbox_shape_double_jump: CollisionShape2D = $HitboxArea/HitboxShape_DoubleJump
@onready var hitbox_shape_glide: CollisionShape2D = $HitboxArea/HitboxShape_Glide
@onready var hitbox_shape_swim: CollisionShape2D = $HitboxArea/HitboxShape_Swim
@onready var hitbox_shape_wings: CollisionShape2D = $HitboxArea/HitboxShape_Wings

func _ready() -> void:
	super._ready()
	_update_shapes("default")

func _update_skin_appearance() -> void:
	super._update_skin_appearance()

	# Determine which animation is playing based on features
	# This logic mirrors BasePlayer._update_skin_appearance
	var animation_name := "default"

	if wings_feature and wings_feature.enabled:
		animation_name = "wings"
	elif swim_feature and swim_feature.enabled:
		animation_name = "swim"
	elif glide_feature and glide_feature.enabled:
		animation_name = "glide"
	elif double_jump_feature and double_jump_feature.enabled:
		animation_name = "double-jump"

	_update_shapes(animation_name)

func _update_shapes(animation_name: String) -> void:
	# Disable all shapes first
	_disable_all_shapes()

	# Enable specific shapes based on animation
	match animation_name:
		"wings":
			if physics_shape_wings: physics_shape_wings.disabled = false
			if hitbox_shape_wings: hitbox_shape_wings.disabled = false
		"swim":
			if physics_shape_swim: physics_shape_swim.disabled = false
			if hitbox_shape_swim: hitbox_shape_swim.disabled = false
		"glide":
			if physics_shape_glide: physics_shape_glide.disabled = false
			if hitbox_shape_glide: hitbox_shape_glide.disabled = false
		"double-jump":
			if physics_shape_double_jump: physics_shape_double_jump.disabled = false
			if hitbox_shape_double_jump: hitbox_shape_double_jump.disabled = false
		_:
			# Default fallback
			if physics_shape_default: physics_shape_default.disabled = false
			if hitbox_shape_default: hitbox_shape_default.disabled = false

func _disable_all_shapes() -> void:
	if physics_shape_default: physics_shape_default.disabled = true
	if physics_shape_double_jump: physics_shape_double_jump.disabled = true
	if physics_shape_glide: physics_shape_glide.disabled = true
	if physics_shape_swim: physics_shape_swim.disabled = true
	if physics_shape_wings: physics_shape_wings.disabled = true

	if hitbox_shape_default: hitbox_shape_default.disabled = true
	if hitbox_shape_double_jump: hitbox_shape_double_jump.disabled = true
	if hitbox_shape_glide: hitbox_shape_glide.disabled = true
	if hitbox_shape_swim: hitbox_shape_swim.disabled = true
	if hitbox_shape_wings: hitbox_shape_wings.disabled = true
