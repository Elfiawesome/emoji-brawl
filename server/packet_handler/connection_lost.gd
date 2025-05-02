extends Node
# Undo whatever we did in connection_request
# Basically just remove whatever is left of the player off the server
# THe Server.Client object will be deleted by itself so dont need to worry about that

func run(server: Server, client: Server.ClientBase, _data: Array) -> void: 
	if client.id != "":
		if server.clients.has(client.id):
			if (client.current_world_id) and (client.current_world_id in server.world_manager.worlds):
				server.world_manager.worlds[client.current_world_id].avatar_manager.remove_avatar_for_client(client.id)
			server.clients.erase(client.id)
	else:
		pass
