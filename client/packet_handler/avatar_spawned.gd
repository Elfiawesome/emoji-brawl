## Handles the 'avatar_spawned' packet from the server.
extends PacketHandlerClient

# Spawns a new avatar based on server data.
func run(game: GameSession, data: Array) -> void:
	if !validate_data(data):
		printerr("Invalid 'avatar_spawned' packet received. Data: ", data)
		return

	if !game.world:
		printerr("'avatar_spawned': World is not loaded!")
		return

	var avatar_id: String = data[0]
	var initial_avatar_state: Dictionary = data[1]

	game.world.avatar_manager.spawn_avatar(avatar_id, initial_avatar_state)


# Validates the data structure for the 'avatar_spawned' packet.
# Expected: [String avatar_id, Dictionary initial_state]
func validate_data(data: Array) -> bool:
	if data.size() != 2:
		printerr("Validation fail: Expected 2 arguments, got ", data.size())
		return false
	if not data[0] is String:
		printerr("Validation fail: Argument 0 (avatar_id) should be String, got ", typeof(data[0]))
		return false
	if not data[1] is Dictionary:
		printerr("Validation fail: Argument 1 (initial_state) should be Dictionary, got ", typeof(data[1]))
		return false
	return true