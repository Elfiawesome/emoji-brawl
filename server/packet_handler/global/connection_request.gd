extends PacketHandlerServer

func run(server: Server, data: Array, conn: NetworkServerManager.Connection) -> void:
	if !Schema.is_valid(data, [TYPE_DICTIONARY]): return
	
	var request_data: Dictionary = data[0]
	var username: String = request_data.get("username", "")

	var hash_id := username # TODO: hash the username
	if hash_id in server.network_manager.connections:
		conn.force_disconnect("A username is already in this server!")
		return
	
	server.network_manager.connections[hash_id] = conn
	conn.id = hash_id
	
	# load player data from save
	server.create_player_state(conn.id)
	
	var target_map_id: String = "lobby"
	if server.global_player_states[conn.id].last_map_id:
		target_map_id = server.global_player_states[conn.id].last_map_id
	
	server.load_map(target_map_id)
	var space_id := server.space_manager.maps_loaded[target_map_id]
	server.space_manager.assign_client_to_space(conn.id, space_id)
	server.global_player_states[conn.id].last_map_id = target_map_id
