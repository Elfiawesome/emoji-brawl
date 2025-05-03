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
	client.color = data[1]
	client.id = hash_id
	client.state = client.State.PLAY
	
	var world := server.world_manager.get_random_world()
	world.add_client(client)



func validate_data(data: Array) -> bool:
	if data.size() != 2: return false
	if !(data[0] is String): return false # username
	if !(data[1] is Color): return false # custom set color
	return true
