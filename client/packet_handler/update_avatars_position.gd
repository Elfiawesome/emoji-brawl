extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if data.size() == 1:
		var avatars_data: Dictionary = data[0]
		
		for avatar_id: String in avatars_data:
			var pos: Vector2 = avatars_data[avatar_id]
			if avatar_id in game.avatars:
				game.avatars[avatar_id]._update_position(pos)
