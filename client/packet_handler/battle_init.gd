extends PacketHandlerClient

# Instantiates and displays the battle scene.
func run(game: GameSession, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'battle_init' packet received. Data: ", data)
		return

	# Prevent initializing battle if one already exists
	if game.battle:
		printerr("'battle_init': Battle already in progress.")
		return

	# TODO: Deserialize battle_state into game.battle
	var _battle_state: Dictionary = data[0] # Currently unused, but validated

	# Instantiate and add the battle scene
	var new_battle: Battle = game.BATTLE_SCENE.instantiate() as Battle
	if !new_battle:
		printerr("'battle_init': Failed to instantiate Battle scene.")
		return
		
	game.battle = new_battle
	game.battle_layer.add_child(game.battle)
	# Potentially deserialize battle_state into game.battle here in the future


# Validates the data structure for the 'battle_init' packet.
# Expected: [Dictionary battle_state]
func validate_data(data: Array) -> bool:
	if data.size() != 1:
		printerr("Validation fail: Expected 1 argument, got ", data.size())
		return false
	if not data[0] is Dictionary:
		printerr("Validation fail: Argument 0 (battle_state) should be Dictionary, got ", typeof(data[0]))
		return false
	return true
