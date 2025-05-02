extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if !validate_data(data):
		printerr("Invalid 'avatar_spawned' packet received.")
		return
	
	var avatar_id: String = data[0]
	var initial_avatar_state: Dictionary = data[1]
	
	game.avatar_manager.spawn_avatar(avatar_id, initial_avatar_state)

func validate_data(data: Array) -> bool:
	if data.size() != 2: return false
	if !(data[0] is String): return false # avatar_id
	if !(data[1] is Dictionary): return false # initial state
	return true
