extends PacketHandlerClient

var AVATAR := preload("res://client/avatar.tscn")

func run(game: GameSession, data: Array) -> void:
	if data.size() == 3:
		var avatar_id: String = data[0]
		var is_local: bool = data[1]
		var avatar_data: Dictionary = data[2]
		
		if is_local:
			game.local_avatar_id = avatar_id
		
		var avatar: Avatar = AVATAR.instantiate()
		avatar.is_local = is_local
		game.add_child(avatar)
		game.avatars[avatar_id] = avatar
		
		
		if avatar_data:
			avatar.position = avatar_data.get("position", Vector2.ZERO)
