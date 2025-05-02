class_name AvatarClientManager extends Node

var game_session: GameSession
var network_connection: GameSession.NetworkConnectionBase

const AVATAR_SCENE := preload("res://client/avatar.tscn")

var avatars: Dictionary[String, Avatar] = {}
var local_avatar_id: String # Used to find the local avatar to do immediate local movement

func _init(game_session_: GameSession, network_connection_: GameSession.NetworkConnectionBase) -> void:
	name = "AvatarClientManager"
	game_session = game_session_
	network_connection = network_connection_

func _process(delta: float) -> void:
	process_local_input(delta)

func predict_local_avatar_movement(movement: Vector2) -> void:
	# Apply movement directly to local avatar for responsiveness
	if (local_avatar_id) and (local_avatar_id in avatars):
		var local_avatar := avatars[local_avatar_id]
		local_avatar.position += movement

func set_local_avatar_id(local_avatar_id_: String) -> void:
	if local_avatar_id:
		if local_avatar_id in avatars:
			avatars[local_avatar_id].set_is_local(false)
	
	if local_avatar_id_ in avatars:
		local_avatar_id = local_avatar_id_
		avatars[local_avatar_id].set_is_local(true)

func spawn_avatar(avatar_id: String, inital_state:Dictionary) -> void:
	var avatar := AVATAR_SCENE.instantiate()
	game_session.add_child(avatar)
	
	avatar.deserialize(inital_state)
	# SPECIAL CASE: the position need not lerp but can be set immediately
	avatar.position = inital_state.get("pos", avatar.position)
	
	avatars[avatar_id] = avatar

func despawn_avatar(avatar_id: String) -> void:
	if avatar_id in avatars:
		avatars[avatar_id].queue_free()

func process_local_input(delta: float) -> void:
	if not local_avatar_id: return # No local avatar to control
	
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_direction != Vector2.ZERO:
		# 1. Predict movement locally
		var move_vector := input_direction.normalized() * AvatarServerManager.MOVEMENT_SPEED * delta
		predict_local_avatar_movement(move_vector)
		
		# 2. Send input to server
		network_connection.send_data("avatar_input", [input_direction, delta])
