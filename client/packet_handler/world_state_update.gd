extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if !validate_data(data):
		printerr("Invalid 'world_state_update' packet received.")
		return
	
	var world_state: Dictionary = data[0]
	
	if game.world:
		game.world.deserialize(world_state)
	else:
		game.create_world(world_state)

func validate_data(data: Array) -> bool:
	if data.size() != 1: return false
	if !(data[0] is Dictionary): return false # states dictionary
	return true
