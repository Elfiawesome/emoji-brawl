extends PacketHandlerServer

func run(server: Server, client: Server.ClientBase, data: Array) -> void: 
	if !validate_data(data):
		printerr("Invalid 'request_change_world' packet received.")
		return
	
	if client.current_battle_id:
		return
	
	# Unload that person from the old orld
	if client.current_world_id:
		var old_world := server.world_manager.worlds[client.current_world_id]
		old_world.remove_client(client)
	
	# Load that player into the new world
	var new_world := server.world_manager.get_random_world()
	if new_world:
		new_world.add_client(client)




func validate_data(data: Array) -> bool:
	if data.size() != 0: return false
	#if !(data[0] is String): return false # world_id
	return true
