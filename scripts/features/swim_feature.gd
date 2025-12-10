## SwimFeature - Lets you swim faster underwater
##
## This feature increases movement speed when the character is in UnderWaterTerrain.
## Always active if enabled (passive ability).
class_name SwimFeature
extends Feature

# === PUBLIC VARIABLES ===
var swim_speed_multiplier: float

# === BUILT-IN METHODS ===
func _ready() -> void:
	feature_name = "Swim"
	_setup_tweakables()
	# Passive feature, always active if enabled
	if enabled:
		activate()

func _setup_tweakables() -> void:
	swim_speed_multiplier = FeatureConstants.get_value("Swim", "swim_speed_multiplier")
	FeatureConstants.value_changed.connect(_on_tweakable_changed)

func _on_tweakable_changed(category: String, key: String, value: Variant) -> void:
	if category == "Swim":
		match key:
			"swim_speed_multiplier": swim_speed_multiplier = float(value)

# === PUBLIC METHODS ===

## Get swim speed multiplier
func get_swim_speed_multiplier() -> float:
	if is_active():
		return swim_speed_multiplier
	return 1.0
