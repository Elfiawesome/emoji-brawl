extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'world_init' packet received.")
		return
	
	if !game.world:
		printerr("World is not loaded to 'world_init'!")
		return
	
	game.world.avatar_manager.local_avatar_id = data[0]

func validate_data(data: Array) -> bool:
	if data.size() != 1: return false
	if not (data[0] is String): return false
	return true
