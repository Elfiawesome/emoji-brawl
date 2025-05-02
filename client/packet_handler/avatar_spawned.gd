extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'avatar_spawned' packet received.")
		return
	
	var avatar_id: String = data[0]
	var initial_state: Dictionary = data[1]

	# Spawn as a remote avatar
	game.avatar_manager.spawn_avatar(avatar_id, initial_state, false)

func validate_data(data: Array) -> bool:
	if data.size() != 2: return false
	if not (data[0] is String): return false     # avatar_id
	if not (data[1] is Dictionary): return false # initial_state
	return true
