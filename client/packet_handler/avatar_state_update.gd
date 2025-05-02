extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'avatar_state_update' packet received.")
		return
	
	var states: Dictionary = data[0]
	
	for avatar_id: String in states:
		var state_data: Dictionary = states[avatar_id]
		game.avatar_manager.update_avatar_state(avatar_id, state_data)

func validate_data(data: Array) -> bool:
	if data.size() != 1: return false
	if not (data[0] is Dictionary): return false # states dictionary
	return true
