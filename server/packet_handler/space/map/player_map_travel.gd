extends SpacePacketHandlerServer

func run(server: Server, data: Array, conn: NetworkServerManager.Connection) -> void:
	# Get current world so that we dont choose that world
	var current_space_id := server.space_manager._client_to_spaces[conn.id]
	var current_space := server.space_manager.spaces[current_space_id]
	if current_space is SpaceMap:
		var loaded_map := server.space_manager.maps_loaded.keys().duplicate()
		loaded_map.erase(current_space.map_id)
		var target_map_id: String = loaded_map.pick_random()
		
		if target_map_id in server.space_manager.maps_loaded:
			var space_id := server.space_manager.maps_loaded[target_map_id]
			
			server.space_manager.deassign_client_from_space(conn.id)
			server.space_manager.assign_client_to_space(conn.id, space_id)
