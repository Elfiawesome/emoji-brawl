extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'battle_init' packet received.")
		return
	
	if game.battle:
		return
	
	game.battle = game.BATTLE_SCENE.instantiate()
	game.battle_layer.add_child(game.battle)

func validate_data(data: Array) -> bool:
	if data.size() != 1: return false
	if not (data[0] is Dictionary): return false # battle state
	return true
