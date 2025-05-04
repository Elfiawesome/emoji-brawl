extends SpacePacketHandlerServer

func run(server: Server, data: Array, conn: NetworkServerManager.Connection) -> void:
	# Get current world so that we dont choose that world
	var current_space_id := server.space_manager._client_to_spaces[conn.id]
	var current_space := server.space_manager.spaces[current_space_id]
	if current_space is SpaceMap:
		var map_options := ["willow", "midtown"]
		map_options.erase(current_space.map_id)
		if map_options.is_empty(): return # No other loaded worlds
		var target_map_id: String = map_options.pick_random()
		
		server.load_map(target_map_id)
		server.global_player_states[conn.id].last_map_id = target_map_id
		var space_id := server.space_manager.maps_loaded[target_map_id]
		server.space_manager.assign_client_to_space(conn.id, space_id)
		
		if current_space.connected_clients.is_empty():
			server.unload_map(current_space.map_id)
