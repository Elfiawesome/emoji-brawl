extends PacketHandlerServer

# Processes the client's connection details, assigns an ID, adds them to the server,
# Finalizes client registration on the server.
# and places them into a world.
func run(server: Server, client: Server.ClientBase, data: Array) -> void:
	if not validate_data(data):
		printerr("Invalid 'connection_request' packet from potential client. Data: ", data)
		client.force_disconnect("Invalid connection request format.") # Disconnect client sending bad data
		return

	# Prevent processing if the client is already in the PLAY state (double request?)
	if client.state == Server.ClientBase.State.PLAY:
		printerr("'connection_request': Client (potential ID: '", client.id ,"') sent request while already in PLAY state. Ignoring.")
		return
		
	# Allow processing if state is NONE or REQUEST
	client.state = Server.ClientBase.State.REQUEST # Mark as processing request

	var username: String = data[0]
	var color: Color = data[1]

	# --- Validation and Setup ---
	if username.strip_edges() == "":
		printerr("'connection_request': Client provided an empty username.")
		client.force_disconnect("Username cannot be empty.")
		return

	# Use username directly as ID for simplicity. Consider hashing or UUIDs for robustness.
	var client_id := username
	if server.clients.has(client_id):
		printerr("'connection_request': Username '", username, "' is already taken.")
		client.force_disconnect("Username already in use on this server.")
		return

	# --- Add Client to Server ---
	client.username = username
	client.color = color
	client.id = client_id # Assign the official ID
	server.clients[client_id] = client # Add to the main server list

	# --- Place Client in a World ---
	if !server.world_manager:
		printerr("'connection_request': World manager is invalid. Cannot place client '", client_id, "' in world.")
		client.force_disconnect("Server error: World manager not available.")
		# Also remove from server.clients list as the setup failed
		server.clients.erase(client_id)
		return

	var target_world: WorldServerManager.WorldServer = server.world_manager.get_random_world()
	if !target_world:
		printerr("'connection_request': Failed to get a valid world for client '", client_id, "'.")
		client.force_disconnect("Server error: No available worlds.")
		server.clients.erase(client_id) # Clean up failed registration
		return

	# Add the client to the chosen world (this also handles sending world_init to the client)
	var added_to_world: bool = target_world.add_client(client)
	
	if not added_to_world:
		printerr("'connection_request': Failed to add client '", client_id,"' to world '", target_world.world_id, "'.")
		# add_client should have force_disconnected client if it failed critically.
		# If it returns false for a non-critical reason, we might need more handling here.
		# Ensure client is removed if addition failed.
		if server.clients.has(client_id):
			server.clients.erase(client_id)
		return # Stop processing if world add failed

	# --- Finalize State ---
	client.state = Server.ClientBase.State.PLAY # Client is now fully connected and in the game world
	print("Client '", client.id, "' ('", client.username, "') successfully connected and joined world '", client.current_world_id, "'.")


# Validates the data structure for the 'connection_request' packet.
# Expected: [String username, Color color]
func validate_data(data: Array) -> bool:
	if data.size() != 2:
		printerr("Validation fail: Expected 2 arguments, got ", data.size())
		return false
	if not data[0] is String:
		printerr("Validation fail: Argument 0 (username) should be String, got ", typeof(data[0]))
		return false
	if not data[1] is Color:
		printerr("Validation fail: Argument 1 (color) should be Color, got ", typeof(data[1]))
		return false
	return true
