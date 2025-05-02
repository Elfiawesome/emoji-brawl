class_name Avatar extends Node2D

var target_position: Vector2
var _is_local: bool = false

const RECONCILE_LERP_FACTOR = 0.2

func _ready() -> void:
	target_position = position

func set_is_local(local_status: bool) -> void:
	_is_local = local_status

func set_target_position(new_pos: Vector2) -> void:
	target_position = new_pos

func set_username_label(username: String) -> void:
	$Label.text = username

func reconcile_position(server_pos: Vector2) -> void:
	position = lerp(position, server_pos, RECONCILE_LERP_FACTOR)

func _process(delta: float) -> void:
	if !_is_local:
		position = lerp(position, target_position, delta * 10.0)
