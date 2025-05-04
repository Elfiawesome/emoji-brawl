extends PacketHandlerServer
# Reverse of connection_request
# Clean up all instances from this client

func run(server: Server, _data: Array, conn: NetworkServerManager.Connection) -> void:
	if conn.id != "":
		if server.network_manager.connections.has(conn.id):
			server.network_manager.connections.erase(conn.id)
		
		# trigger leave on space
		server.space_manager.deassign_client_from_space(conn.id)
