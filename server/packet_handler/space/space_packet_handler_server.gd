class_name SpacePacketHandlerServer extends PacketHandlerServer
# TODO: Need a rename lol its such a weird class name

func run(server: Server, data: Array, conn: NetworkServerManager.Connection) -> void:
	var space_id: String = server.space_manager._client_to_spaces.get(conn.id, [])
	
	if space_id in server.space_manager.spaces:
		var space := server.space_manager.spaces[space_id]
		# TODO: We need a better way of routing different spaces + better naming of these concepts
		# We don't pass down the conn object because we are limiting the scope of this function in space level only
		if space is SpaceMap:
			scope_run_as_map(space, conn.id, data)

func scope_run_as_map(cspace_map: SpaceMap, _client_id: String, _data: Array) -> void:
	pass
