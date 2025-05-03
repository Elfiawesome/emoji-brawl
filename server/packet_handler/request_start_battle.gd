extends PacketHandlerServer

func run(server: Server, client: Server.ClientBase, data: Array) -> void: 
	if !validate_data(data):
		printerr("Invalid 'request_start_battle' packet received.")
		return
	
	if client.current_battle_id:
		printerr("Client is already in battle.")
		return
	
	if (client.current_world_id) and (client.current_world_id in server.world_manager.worlds):
		var world := server.world_manager.worlds[client.current_world_id]
		var battle := world.battle_manager.create_battle()
		
		client.current_battle_id = battle.id
		client.send_data("battle_init", [{}])





func validate_data(data: Array) -> bool:
	if data.size() != 0: return false
	#if !(data[0] is String): return false # world_id
	return true
