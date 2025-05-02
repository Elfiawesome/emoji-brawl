class_name AvatarClientManager extends Node

var game_session: GameSession
var network_connection: GameSession.NetworkConnectionBase

const AVATAR_SCENE := preload("res://client/avatar.tscn")

var avatar_nodes: Dictionary[String, Avatar] = {}
var local_avatar_id: String

func _init(game_session_: GameSession, network_connection_: GameSession.NetworkConnectionBase) -> void:
	name = "AvatarClientManager"
	game_session = game_session_
	network_connection = network_connection_

func _process(delta: float) -> void:
	process_local_input(delta)

func set_local_avatar_id(id: String) -> void:
	local_avatar_id = id
	if id in avatar_nodes:
		avatar_nodes[id].set_is_local(true)

func spawn_avatar(avatar_id: String, initial_state: Dictionary, is_local: bool) -> void:
	if avatar_id in avatar_nodes:
		push_warning("Avatar %s already spawned." % avatar_id)
		update_avatar_state(avatar_id, initial_state)
		return
	
	var avatar_node: Avatar = AVATAR_SCENE.instantiate()
	avatar_node.name = "Avatar_%s" % avatar_id
	avatar_node.set_is_local(is_local)
	
	if "pos" in initial_state:
		avatar_node.position = initial_state["pos"]
		avatar_node.set_target_position(initial_state["pos"])
	avatar_node.set_username_label(initial_state.get("username", "null"))
	
	avatar_nodes[avatar_id] = avatar_node
	game_session.add_child(avatar_node)

	if (is_local) and (avatar_id == local_avatar_id):
		avatar_node.set_is_local(true)


func despawn_avatar(avatar_id: String) -> void:
	if avatar_id in avatar_nodes:
		print("Despawning avatar %s" % avatar_id)
		var avatar_node := avatar_nodes[avatar_id]
		avatar_nodes.erase(avatar_id)
		avatar_node.queue_free()

		if avatar_id == local_avatar_id:
			print("Local avatar despawned.")
			local_avatar_id = ""
	else:
		push_warning("Tried to despawn unknown avatar %s" % avatar_id)


func update_avatar_state(avatar_id: String, state_data: Dictionary) -> void:
	if avatar_id in avatar_nodes:
		var avatar_node := avatar_nodes[avatar_id]
		var server_pos: Vector2 = state_data.get("pos", avatar_node.position)
		var username: String = state_data.get("username", avatar_node.position)
		
		if avatar_id == local_avatar_id:
			# Local avatar: Reconcile with server state
			avatar_node.reconcile_position(server_pos)
		else:
			# Remote avatar: Update target for interpolation
			avatar_node.set_target_position(server_pos)
		
		avatar_node.set_username_label(username)


func predict_local_avatar_movement(movement: Vector2) -> void:
	# Apply movement directly to local avatar for responsiveness
	if (local_avatar_id) and (local_avatar_id in avatar_nodes):
		var local_avatar := avatar_nodes[local_avatar_id]
		local_avatar.position += movement


func clear_all_avatars() -> void:
	print("Clearing all avatars.")
	for avatar_id in avatar_nodes:
		avatar_nodes[avatar_id].queue_free()
	avatar_nodes.clear()
	local_avatar_id = ""

func process_local_input(delta: float) -> void:
	if not local_avatar_id: return # No local avatar to control
	
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_direction != Vector2.ZERO:
		# 1. Predict movement locally
		var move_vector := input_direction.normalized() * AvatarServerManager.MOVEMENT_SPEED * delta
		predict_local_avatar_movement(move_vector)
		
		# 2. Send input to server
		network_connection.send_data("avatar_input", [input_direction, delta])
