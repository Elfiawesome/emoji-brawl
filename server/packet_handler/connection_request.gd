extends PacketHandlerServer
## IMPORTANT BECAUSE WE DO THE INITIALIZING AND HANDSHAKE HERE!

func run(server: Server, client: Server.ClientBase, data: Array) -> void: 
	if !validate_data(data): return
	
	if client.state == client.State.PLAY:
		# Meaning the client tried to do a connection request again for some reason
		return
	
	client.state = client.State.REQUEST
	
	var username: String = data[0]
	var hash_id := username
	if hash_id in server.clients:
		client.force_disconnect("A username is already in this server!")
		return
	
	server.clients[hash_id] = client
	client.username = username
	client.id = hash_id
	client.state = client.State.PLAY
	
	var avatar_state := server.avatar_manager.create_avatar(client.id, username)
	if not avatar_state:
		client.force_disconnect("Failed to create avatar on server.")
		return
	
	client.controlled_avatar_id = avatar_state.avatar_id
	
	var initial_self_state := { "pos": avatar_state.position, "username": username }
	var other_avatars_state := server.avatar_manager.get_full_state_for_others(avatar_state.avatar_id)
	
	# Tell connecting client the current game state
	server.network_bus.send_data(client.id, "welcome", [
		avatar_state.avatar_id,
		initial_self_state,
		other_avatars_state
	])
	
	var other_clients := server.clients.keys().duplicate()
	other_clients.erase(client.id)
	server.network_bus.broadcast_specific_data(other_clients, "avatar_spawned", [
		avatar_state.avatar_id,
		initial_self_state
	])

func validate_data(data: Array) -> bool:
	if data.size() != 1: return false
	if !(data[0] is String): return false
	return true
