extends PacketHandlerServer

func run(server: Server, client: Server.ClientBase, data: Array) -> void:
	if data.size() == 1:
		if data[0] is Vector2:
			client.avatar_position = data[0]
			client.is_avatar_changed = true
