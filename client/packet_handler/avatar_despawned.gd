extends PacketHandlerClient

# Despawns an avatar identified by its ID.
func run(game: GameSession, data: Array) -> void:
	if !validate_data(data):
		printerr("Invalid 'avatar_despawned' packet received. Data: ", data)
		return

	if !game.world:
		printerr("'avatar_despawned': World is not loaded!")
		return

	var avatar_id: String = data[0]

	game.world.avatar_manager.despawn_avatar(avatar_id)


# Validates the data structure for the 'avatar_despawned' packet.
# Expected: [String avatar_id]
func validate_data(data: Array) -> bool:
	if data.size() != 1:
		printerr("Validation fail: Expected 1 argument, got ", data.size())
		return false
	if not data[0] is String:
		printerr("Validation fail: Argument 0 (avatar_id) should be String, got ", typeof(data[0]))
		return false
	return true
