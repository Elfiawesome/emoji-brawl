extends PacketHandlerServer
## IMPORTANT BECAUSE WE DO THE INITIALIZING AND HANDSHAKE HERE!

func run(server: Server, client: Server.ClientBase, data: Array) -> void: 
	if !validate_data(data):
		printerr("Invalid 'connection_request' packet received.")
		return
	
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
	
	# Create avatar for this player
	var avatar_state := server.avatar_manager.create_avatar(client.id, username)
	if not avatar_state:
		client.force_disconnect("Failed to create avatar on server.")
		return
	avatar_state.color = data[1]
	# Set controller so when server receive from this client, we know which avatar it's talking about
	client.controlled_avatar_id = avatar_state.avatar_id
	var serialized_avatar_state := avatar_state.serialize()
	
	var serialized_avatar_states := {}
	for _avatar_id in server.avatar_manager.avatars:
		var _avatar_state := server.avatar_manager.avatars[_avatar_id]
		serialized_avatar_states[_avatar_id] = _avatar_state.serialize()
	server.network_bus.broadcast_data("avatar_state_update", [serialized_avatar_states])
	
	server.network_bus.send_data(client.id, "world_init", [avatar_state.avatar_id])

func validate_data(data: Array) -> bool:
	if data.size() != 2: return false
	if !(data[0] is String): return false # username
	if !(data[1] is Color): return false # custom set color
	return true
