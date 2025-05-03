extends PacketHandlerServer

func run(server: Server, client: Server.ClientBase, data: Array) -> void:
	if not validate_data(data):
		push_warning("Client %s sent invalid avatar input data." % client.id)
		return
	
	if not client.current_world_id:
		push_warning("Client %s sent input but is not in any world." % client.id)
		return
	
	if not client.controlled_avatar_id:
		push_warning("Client %s sent input but has no controlled avatar." % client.id)
		return
	
	
	var input_direction: Vector2 = data[0]
	var delta: float = data[1]
	
	# Route to correct work
	if (client.current_world_id) and (client.current_world_id in server.world_manager.worlds):
		server.world_manager.worlds[client.current_world_id].avatar_manager.process_input(client.controlled_avatar_id, input_direction, delta)


func validate_data(data: Array) -> bool:
	if data.size() != 2: return false
	if not (data[0] is Vector2): return false # movement direction
	if not (data[1] is float): return false # client's delta
	return true
