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

	# Use the actual animation being played by the skin
	# This ensures we are always in sync with BasePlayer's logic
	if skin and skin.animated_sprite:
		_update_shapes(skin.animated_sprite.animation)
	else:
		_update_shapes("default")

func _update_shapes(animation_name: String) -> void:
	# Disable all shapes first
	_disable_all_shapes()

	# Enable specific shapes based on animation
	match animation_name:
		"wings":
			if physics_shape_wings: physics_shape_wings.set_deferred("disabled", false)
			if hitbox_shape_wings: hitbox_shape_wings.set_deferred("disabled", false)
		"swim":
			if physics_shape_swim: physics_shape_swim.set_deferred("disabled", false)
			if hitbox_shape_swim: hitbox_shape_swim.set_deferred("disabled", false)
		"glide":
			if physics_shape_glide: physics_shape_glide.set_deferred("disabled", false)
			if hitbox_shape_glide: hitbox_shape_glide.set_deferred("disabled", false)
		"double-jump":
			if physics_shape_double_jump: physics_shape_double_jump.set_deferred("disabled", false)
			if hitbox_shape_double_jump: hitbox_shape_double_jump.set_deferred("disabled", false)
		_:
			if physics_shape_default: physics_shape_default.set_deferred("disabled", false)
			if hitbox_shape_default: hitbox_shape_default.set_deferred("disabled", false)

func _disable_all_shapes() -> void:
	if physics_shape_default: physics_shape_default.set_deferred("disabled", true)
	if physics_shape_double_jump: physics_shape_double_jump.set_deferred("disabled", true)
	if physics_shape_glide: physics_shape_glide.set_deferred("disabled", true)
	if physics_shape_swim: physics_shape_swim.set_deferred("disabled", true)
	if physics_shape_wings: physics_shape_wings.set_deferred("disabled", true)

	if hitbox_shape_default: hitbox_shape_default.set_deferred("disabled", true)
	if hitbox_shape_double_jump: hitbox_shape_double_jump.set_deferred("disabled", true)
	if hitbox_shape_glide: hitbox_shape_glide.set_deferred("disabled", true)
	if hitbox_shape_swim: hitbox_shape_swim.set_deferred("disabled", true)
	if hitbox_shape_wings: hitbox_shape_wings.set_deferred("disabled", true)
