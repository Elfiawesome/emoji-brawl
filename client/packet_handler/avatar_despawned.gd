extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if !validate_data(data):
		printerr("Invalid 'avatar_despawned' packet received.")
		return
	
	var avatar_id: String = data[0]
	
	game.avatar_manager.despawn_avatar(avatar_id)

func validate_data(data: Array) -> bool:
	if data.size() != 1: return false
	if !(data[0] is String): return false # avatar_id
	return true
