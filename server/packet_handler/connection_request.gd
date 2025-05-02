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
	client.id = hash_id
	client.state = client.State.PLAY
	
	client.avatar_id = UUID.v4()
	var starting_avatar_data := {"position":Vector2(200, 200)}
	
	for client_id in server.clients:
		var _client := server.clients[client_id]
		if client_id != client.id:
			# Tell this guy everyone's data
			server.network_bus.send_data(client.id, "create_avatar", [_client.avatar_id, false, {"position": _client.avatar_position}])
		else:
			# Tell this guy his data
			server.network_bus.send_data(client.id, "create_avatar", [client.avatar_id, true, starting_avatar_data])
	for client_id in server.clients:
		if client_id != client.id:
			# Tell everyone this guys data
			server.network_bus.send_data(client_id, "create_avatar", [client.avatar_id, false, starting_avatar_data])


func validate_data(data: Array) -> bool:
	if data.size() != 1: return false
	if !(data[0] is String): return false
	return true
