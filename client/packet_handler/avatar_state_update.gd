extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if !validate_data(data):
		printerr("Invalid 'avatar_state_update' packet received.")
		return
	
	if !game.world:
		printerr("World is not loaded to 'avatar_state_update'!")
		return
	
	var states: Dictionary = data[0]
	
	for avatar_id: String in states:
		var state_data: Dictionary = states[avatar_id]
		
		if avatar_id in game.world.avatar_manager.avatars:
			var avatar := game.world.avatar_manager.avatars[avatar_id]
			avatar.deserialize(state_data)
		else:
			game.world.avatar_manager.spawn_avatar(avatar_id, state_data)

func validate_data(data: Array) -> bool:
	if data.size() != 1: return false
	if !(data[0] is Dictionary): return false # states dictionary
	return true
