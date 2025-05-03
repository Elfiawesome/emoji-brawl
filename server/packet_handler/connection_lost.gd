extends PacketHandlerServer
## Handles the cleanup process when a client connection is lost or intentionally closed.
## This handler is typically triggered internally by the Server/ClientBase logic,
## not directly by a packet from the client.

# Cleans up server-side resources associated with the disconnected client.
# Note: This 'run' is called internally, not by network directly.
func run(server: Server, client: Server.ClientBase, _data: Array) -> void:
	# Data might contain disconnect reason, but isn't strictly needed for cleanup.
	
	print("Connection Lost Handler: Cleaning up for client ID '", client.id, "', Username: '", client.username, "'")
	
	# 1. Remove from current battle (if any)
	if client.current_battle_id != "" and server.world_manager:
		# Battles are managed per-world in this structure
		if client.current_world_id != "" and server.world_manager.worlds.has(client.current_world_id):
			var world : WorldServerManager.WorldServer = server.world_manager.worlds[client.current_world_id]
			if world and world.battle_manager.battles.has(client.current_battle_id):
					var battle : BattleLogic = world.battle_manager.battles[client.current_battle_id]
					if battle:
						battle.remove_player(client.id)
						# TODO: Check if battle should end after player removal
					else:
						printerr("Connection Lost: Client '", client.id,"' was in battle '", client.current_battle_id,"' but battle instance is invalid.")
			else:
				printerr("Connection Lost: Client '", client.id,"' was in battle '", client.current_battle_id,"' but world '", client.current_world_id)
		else:
			printerr("Connection Lost: Client '", client.id,"' was in battle '", client.current_battle_id,"' but their world '", client.current_world_id, "' is unknown or invalid.")
	
	# 2. Remove from current world and despawn avatar (if any)
	if client.current_world_id != "" and server.world_manager:
		if server.world_manager.worlds.has(client.current_world_id):
			var world: WorldServerManager.WorldServer = server.world_manager.worlds[client.current_world_id]
			if world:
				# world.remove_client takes care of avatar removal within that world
				world.remove_client(client) 
			else:
				printerr("Connection Lost: Client '", client.id,"' was in world '", client.current_world_id,"' but world instance is invalid.")
		else:
			printerr("Connection Lost: Client '", client.id,"' was in world '", client.current_world_id,"' which does not exist on the server.")

	# 3. Remove from the main server client list
	if client.id != "" and server.clients.has(client.id):
		server.clients.erase(client.id)
		print("Connection Lost Handler: Client '", client.id, "' removed from server list.")
	elif client.id != "":
		printerr("Connection Lost Handler: Client '", client.id, "' was not found in the server's client list during cleanup.")
	else:
		# This case might happen if the client disconnected before sending connection_request
		print("Connection Lost Handler: Cleaning up client that never fully registered (no ID assigned).")

	# Note: The ClientBase node instance itself is queue_free'd by the calling code (e.g., in ClientBase.force_disconnect).


# No validation needed as this isn't processing direct client input.
# func validate_data(data: Array) -> bool:
#	 return true
