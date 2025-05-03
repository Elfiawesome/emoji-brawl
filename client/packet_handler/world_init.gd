extends PacketHandlerClient

const TRANSITION_DURATION: float = 0.25

# Initializes the world, assigns the local avatar, and performs a basic screen transition.
func run(game: GameSession, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'world_init' packet received. Data: ", data)
		return

	var local_avatar_id: String = data[0]
	var world_state: Dictionary = data[1]

	var old_world: World = game.world
	game.world = null

	# Create new world
	game.create_world(world_state)
	var new_world := game.world
	if !new_world:
		printerr("'world_init': Failed to create new world instance.")
		return

	new_world.visible = false
	
	new_world.avatar_manager.set_local_avatar_id(local_avatar_id)
	
	var tween: Tween = game.create_tween()
	tween.set_parallel(true)
	# Fade out
	tween.tween_property(game.world_transition, ^"visible", true, 0.0)
	tween.tween_property(game.world_transition, ^"color:a", 1.0, TRANSITION_DURATION)
	tween.chain().tween_callback(
		func() -> void:
			if old_world:
				old_world.queue_free()
			if new_world:
				new_world.visible = true # Make new world visible now
	)
	tween.chain().tween_property(game.world_transition, ^"color:a", 0.0, TRANSITION_DURATION)
	tween.chain().tween_property(game.world_transition, ^"visible", false, 0.0)


# Validates the data structure for the 'world_init' packet.
# Expected: [String local_avatar_id, Dictionary world_state]
func validate_data(data: Array) -> bool:
	if data.size() != 2:
		printerr("Validation fail: Expected 2 arguments, got ", data.size())
		return false
	if not data[0] is String:
		printerr("Validation fail: Argument 0 (local_avatar_id) should be String, got ", typeof(data[0]))
		return false
	if not data[1] is Dictionary:
		printerr("Validation fail: Argument 1 (world_state) should be Dictionary, got ", typeof(data[1]))
		return false
	return true
