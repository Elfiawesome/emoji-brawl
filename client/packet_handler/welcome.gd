extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if !validate_data(data):
		printerr("Invalid 'welcome' packet received.")
		return
	
	var own_avatar_id: String = data[0]
	var own_initial_state: Dictionary = data[1]
	var other_avatars_state: Dictionary = data[2]
	
	game.avatar_manager.set_local_avatar_id(own_avatar_id)
	
	game.avatar_manager.spawn_avatar(own_avatar_id, own_initial_state, true)
	
	for other_avatar_id: String in other_avatars_state:
		var initial_state: Dictionary = other_avatars_state[other_avatar_id]
		game.avatar_manager.spawn_avatar(other_avatar_id, initial_state, false)

func validate_data(data: Array) -> bool:
	if data.size() != 3: return false
	if not (data[0] is String): return false      # own_avatar_id
	if not (data[1] is Dictionary): return false # own_initial_state
	if not (data[2] is Dictionary): return false # other_avatars_state
	return true
