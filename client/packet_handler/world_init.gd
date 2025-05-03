extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'world_init' packet received.")
		return
	
	var old_world: World
	var new_world: World
	if game.world:
		old_world = game.world
		game.world = null
	game.create_world(data[1])
	new_world = game.world
	new_world.visible = false
	
	game.world.avatar_manager.local_avatar_id = data[0]
	
	var tween := game.create_tween()
	tween.set_parallel(true)
	tween.tween_property(game.world_transition, "visible", true, 0)
	tween.tween_property(game.world_transition, "color:a", 1, 0.25)
	tween.chain().tween_callback(
		func() -> void:
			if old_world: old_world.queue_free()
			if new_world:
				new_world.visible = true
	)
	tween.chain().tween_property(game.world_transition, "color:a", 0, 0.25)
	tween.chain().tween_property(game.world_transition, "visible", false, 0)


func validate_data(data: Array) -> bool:
	if data.size() != 2: return false
	if not (data[0] is String): return false # Target avatar
	if not (data[1] is Dictionary): return false # world state
	return true
