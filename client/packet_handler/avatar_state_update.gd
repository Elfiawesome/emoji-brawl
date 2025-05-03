extends PacketHandlerClient

# Updates the state of existing avatars or spawns them if they don't exist locally.
func run(game: GameSession, data: Array) -> void:
	if !validate_data(data):
		printerr("Invalid 'avatar_state_update' packet received. Data: ", data)
		return

	if !game.world:
		printerr("'avatar_state_update': World is not loaded!")
		return
	
	var states: Dictionary = data[0]

	for avatar_id: String in states:
		var state_data: Dictionary = states[avatar_id]

		if not state_data is Dictionary:
			printerr("'avatar_state_update': Invalid state data for avatar '", avatar_id, "'. Expected Dictionary, got ", typeof(state_data))
			continue # Skip this invalid entry

		if avatar_id in game.world.avatar_manager.avatars:
			var avatar: Avatar = game.world.avatar_manager.avatars[avatar_id]
			if avatar:
				avatar.deserialize(state_data)
			else:
				# Avatar might have been queued for freeing, try spawning again
				printerr("'avatar_state_update': Found avatar_id '", avatar_id, "' in manager but instance is invalid. Respawning.")
				game.world.avatar_manager.spawn_avatar(avatar_id, state_data)
		else:
			# Avatar doesn't exist locally, spawn it
			game.world.avatar_manager.spawn_avatar(avatar_id, state_data)


# Validates the data structure for the 'avatar_state_update' packet.
# Expected: [Dictionary states] where states is { avatar_id: state_dict, ... }
func validate_data(data: Array) -> bool:
	if data.size() != 1:
		printerr("Validation fail: Expected 1 argument, got ", data.size())
		return false
	if not data[0] is Dictionary:
		printerr("Validation fail: Argument 0 (states) should be Dictionary, got ", typeof(data[0]))
		return false
	return true