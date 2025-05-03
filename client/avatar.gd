class_name Avatar extends Node2D

# Target position received from the server, used for interpolation.
var target_position: Vector2
# Flag indicating if this avatar is controlled by the local player.
var _is_local: bool = false

# Factor for smoothing corrections when reconciling predicted local position
# with authoritative server position. Value between 0 and 1.
const RECONCILE_LERP_FACTOR: float = 0.2
# Interpolation speed for remote avatars. Higher value means faster snapping.
const REMOTE_INTERPOLATION_SPEED: float = 20.0

# Keys used for deserializing avatar state data received from the server.
# Should match the keys used in AvatarServerState.serialize().
const KEYS := {
	USERNAME = "username",
	COLOR = "color",
	POSITION = "pos"
}

@onready var label: Label = $Label # username label
#@onready var sprite: Sprite2D = $Sprite2D # Optional reference if needed

func _ready() -> void:
	target_position = position


func _process(delta: float) -> void:
	if not _is_local:
		position = lerp(position, target_position, delta * REMOTE_INTERPOLATION_SPEED)


##Sets whether this avatar instance is controlled by the local player.
func set_is_local(local_status: bool) -> void:
	_is_local = local_status



# Updates the avatar's state based on data received from the server.
func deserialize(state_data: Dictionary) -> void:
	label.text = state_data.get(KEYS.USERNAME, "Unknown")
	modulate = state_data.get(KEYS.COLOR, Color.WHITE)
	
	var server_pos: Vector2 = state_data.get(KEYS.POSITION, position) # Default to current pos if missing
	if _is_local:
		# Client-Side Reconciliation: Smoothly correct the local avatar's position
		# towards the server's authoritative position if they differ significantly.
		# This corrects for prediction errors or latency.
		# Lerp factor determines how quickly the correction happens.
		position = lerp(position, server_pos, RECONCILE_LERP_FACTOR)
		target_position = position # Update target position as well for consistency
	else:
		# Remote avatars simply update their target position for interpolation.
		target_position = server_pos
