## Handles the 'request_start_battle' packet from a client initiating a battle.
extends PacketHandlerServer

# Processes a client's request to start a battle within their current world.
func run(server: Server, client: Server.ClientBase, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'request_start_battle' packet from client '", client.id, "'. Data: ", data)
		return

	# --- State Validation ---
	if client.state != Server.ClientBase.State.PLAY:
		printerr("'request_start_battle': Client '", client.id, "' is not in PLAY state. Ignoring.")
		return

	if client.current_battle_id != "":
		printerr("'request_start_battle': Client '", client.id, "' is already in battle ('", client.current_battle_id, "'). Ignoring.")
		return

	if client.current_world_id == "":
		printerr("'request_start_battle': Client '", client.id, "' is not in a world. Ignoring.")
		return
		
	if not is_instance_valid(server.world_manager):
		printerr("'request_start_battle': World manager is invalid. Cannot process request for client '", client.id, "'.")
		return

	# --- Find World and Create Battle ---
	if not server.world_manager.worlds.has(client.current_world_id):
		printerr("'request_start_battle': Current world '", client.current_world_id, "' not found for client '", client.id, "'.")
		return
		
	var world: WorldServerManager.WorldServer = server.world_manager.worlds[client.current_world_id]
	if not is_instance_valid(world) or not is_instance_valid(world.battle_manager):
		printerr("'request_start_battle': World '", client.current_world_id, "' or its BattleServerManager is invalid for client '", client.id, "'.")
		return

	# TODO: Implement actual matchmaking or battle initiation logic.
	# This currently just creates a solo battle for the requesting client.
	print("Client '", client.id, "' requested to start a battle in world '", client.current_world_id, "'.")
	
	var new_battle: BattleLogic = world.battle_manager.create_battle()
	if not is_instance_valid(new_battle):
		printerr("'request_start_battle': Failed to create battle instance for client '", client.id, "'.")
		# Optionally send an error message back to client
		return

	# Add the requesting player to the battle
	var added_to_battle: bool = new_battle.add_player(client)
	if not added_to_battle:
		printerr("'request_start_battle': Failed to add client '", client.id, "' to the newly created battle '", new_battle.id, "'.")
		# Clean up the potentially empty battle? Or rely on BattleServerManager cleanup?
		# world.battle_manager.remove_battle(new_battle.id) # Need remove_battle function
		return

	# --- Update Client State and Notify ---
	client.current_battle_id = new_battle.id
	print("Client '", client.id, "' started and joined battle '", new_battle.id, "'.")

	# Send confirmation and initial battle state to the client
	# Serialize the initial state (might be mostly empty for now)
	var initial_battle_state: Dictionary = new_battle.serialize()
	client.send_data("battle_init", [initial_battle_state])

	# TODO: Notify other players if it's a multiplayer battle.


# Validates the data structure for the 'request_start_battle' packet.
# Expected: [] (No data arguments)
func validate_data(data: Array) -> bool:
	if not data.is_empty():
		printerr("Validation fail: Expected 0 arguments, got ", data.size())
		return false
	return true
