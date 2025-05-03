extends PacketHandlerServer

# Processes movement input for a client's avatar within their current world.
func run(server: Server, client: Server.ClientBase, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'avatar_input' packet from client '", client.id, "'. Data: ", data)
		return

	# --- Validate Client State ---
	if client.current_world_id == "":
		printerr("'avatar_input': Client '", client.id, "' sent input but is not assigned to any world.")
		return

	if client.controlled_avatar_id == "":
		printerr("'avatar_input': Client '", client.id, "' sent input but has no controlled avatar ID.")
		return
	
	# --- Get World Context ---
	if not server.world_manager or not server.world_manager.worlds.has(client.current_world_id):
		printerr("'avatar_input': Client '", client.id, "' is in world '", client.current_world_id, "' which does not exist on the server.")
		# Perhaps force disconnect or try re-assigning world? For now, just return.
		return
		
	var world: WorldServerManager.WorldServer = server.world_manager.worlds[client.current_world_id]
	if !world or !world.avatar_manager:
		printerr("'avatar_input': World '", client.current_world_id, "' or its AvatarServerManager is invalid for client '", client.id, "'.")
		return

	# --- Process Input ---
	var input_direction: Vector2 = data[0]
	var delta: float = data[1]

	# Clamp delta to prevent speed hacking?
	# const MAX_DELTA = 0.1 # Example limit (adjust based on expected frame rate)
	# if delta <= 0 or delta > MAX_DELTA:
	#	 printerr("'avatar_input': Client '", client.id, "' sent suspicious delta time: ", delta)
	#	 delta = MAX_DELTA # Clamp or ignore input?

	# Route input to the correct world's avatar manager.
	world.avatar_manager.process_input(client.controlled_avatar_id, input_direction, delta)


# Validates the data structure for the 'avatar_input' packet.
# Expected: [Vector2 input_direction, float delta]
func validate_data(data: Array) -> bool:
	if data.size() != 2:
		printerr("Validation fail: Expected 2 arguments, got ", data.size())
		return false
	if not data[0] is Vector2:
		printerr("Validation fail: Argument 0 (input_direction) should be Vector2, got ", typeof(data[0]))
		return false
	# Allow int delta for flexibility, convert later if needed.
	if not (data[1] is float or data[1] is int):
		printerr("Validation fail: Argument 1 (delta) should be float or int, got ", typeof(data[1]))
		return false
	# Add check for delta <= 0?
	if data[1] <= 0.0:
		printerr("Validation fail: Argument 1 (delta) must be positive, got ", data[1])
		return false
		
	return true