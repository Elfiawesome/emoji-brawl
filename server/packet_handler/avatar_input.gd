extends PacketHandlerServer

func run(server: Server, client: Server.ClientBase, data: Array) -> void:
	if not validate_data(data):
		push_warning("Client %s sent invalid avatar input data." % client.id)
		return
	
	if client.state != Server.ClientBase.State.PLAY:
		push_warning("Client %s sent input before PLAY state." % client.id)
		return
	
	if not client.controlled_avatar_id:
		push_warning("Client %s sent input but has no controlled avatar." % client.id)
		return
	
	var input_direction: Vector2 = data[0]
	var delta: float = data[1]

	# Pass validated input to the manager
	server.avatar_manager.process_input(client.controlled_avatar_id, input_direction, delta)


func validate_data(data: Array) -> bool:
	if data.size() != 2: return false # Expecting [Vector2, float]
	if not (data[0] is Vector2): return false
	if not (data[1] is float): return false
	return true
