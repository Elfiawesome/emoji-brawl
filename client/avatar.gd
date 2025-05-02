class_name Avatar extends Node2D

var target_position: Vector2
var _is_local: bool = false

const RECONCILE_LERP_FACTOR = 0.2

func _ready() -> void:
	target_position = position

func _process(delta: float) -> void:
	if !_is_local:
		position = lerp(position, target_position, delta * 10.0)

func set_is_local(local_status: bool) -> void: _is_local = local_status

func deserialize(state_data: Dictionary) -> void:
	$Label.text = state_data.get(KEYS.USERNAME, "Null")
	$Label.modulate = state_data.get(KEYS.COLOR, Color.WHITE)
	var server_pos: Vector2 = state_data.get(KEYS.POSITION, position)
	if _is_local:
		position = lerp(position, server_pos, RECONCILE_LERP_FACTOR)
	else:
		target_position = server_pos

const KEYS = {
	USERNAME = "username",
	COLOR = "color",
	POSITION = "pos"
}
