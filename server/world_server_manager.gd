class_name WorldServerManager extends Node

## Represents a single, self-contained game world instance on the server.
## Includes managers for avatars and battles specific to this world.
class WorldServer extends Node:
	# Unique identifier for this world (e.g., "meadow", "cave_level_1").
	var world_id: String
	# Manages avatars within this world.
	var avatar_manager: AvatarServerManager
	# Manages battles within this world.
	var battle_manager: BattleServerManager
	# World-specific network communication wrapper.
	var network_bus: NetworkBusWrapper

	# Wrapper around the main server NetworkBus to simplify broadcasting
	# only to clients currently connected *to this world*.
	class NetworkBusWrapper extends RefCounted:
		var _main_network_bus: Server.NetworkBus
		# List of client IDs currently present in this world.
		var connected_clients: Array[String] = []

		func _init(main_bus: Server.NetworkBus) -> void:
			if not main_bus: # Check if it's a valid object
				printerr("WorldServer.NetworkBusWrapper: Main network bus instance is null!")
			_main_network_bus = main_bus

		# Adds a client ID to this world's list.
		func add_client(client_id: String) -> void:
			if client_id not in connected_clients:
				connected_clients.push_back(client_id)
				# print("World '", get_parent().world_id, "': Client '", client_id, "' entered. Count: ", connected_clients.size()) # Debug

		# Removes a client ID from this world's list.
		func remove_client(client_id: String) -> void:
			if client_id in connected_clients:
				connected_clients.erase(client_id)
				# print("World '", get_parent().world_id, "': Client '", client_id, "' left. Count: ", connected_clients.size()) # Debug

		# Sends data only to clients currently in this world.
		func broadcast_data(type: String, data: Array) -> void:
			if not _main_network_bus: return
			# Use the main bus's specific broadcast with this world's client list.
			_main_network_bus.broadcast_specific_data(connected_clients, type, data)

		# Sends data to a specific list of clients, *only if* they are in this world.
		# Allows targeting subsets within the world.
		# Set 'inverted' to true to send to everyone in the world *except* those in client_list.
		func broadcast_specific_data(client_list: Array, type: String, data: Array, inverted: bool = false) -> void:
			if not _main_network_bus: return
			
			var target_clients: Array[String] = []
			if inverted:
				# Target = WorldClients - ClientList
				var exclusion_set := {} # Use dictionary as a fast set for lookup
				for id: String in client_list: exclusion_set[id] = true
				
				for client_id: String in connected_clients:
					if not exclusion_set.has(client_id):
						target_clients.push_back(client_id)
			else:
				# Target = WorldClients INTERSECT ClientList
				var world_set := {} # Use dictionary as a fast set for lookup
				for id: String in connected_clients: world_set[id] = true
				
				for client_id: String in client_list:
					if world_set.has(client_id):
						target_clients.push_back(client_id)
						
			if not target_clients.is_empty():
				_main_network_bus.broadcast_specific_data(target_clients, type, data)


		# Sends data to a single client, *only if* they are currently in this world.
		func send_data(client_id: String, type: String, data: Array) -> void:
			if not _main_network_bus: return
			# Check if the client is actually in this world before sending.
			if client_id in connected_clients:
				_main_network_bus.send_data(client_id, type, data)
			# else: # Don't print error, common case if client switches world quickly
			#	 printerr("World '", get_parent().world_id,"' NetworkBus: Tried to send to client '", client_id, "' who is not in this world.")

	# Initialization requires world ID and the main server network bus.
	func _init(p_world_id: String, main_network_bus: Server.NetworkBus) -> void:
		if p_world_id == "": printerr("WorldServer: Attempted to initialize with empty world_id.")
		world_id = p_world_id
		name = "World_" + world_id # Set node name for debugging

		# Create the world-specific network bus wrapper
		network_bus = NetworkBusWrapper.new(main_network_bus)
		if not network_bus: printerr("WorldServer '", world_id, "': Failed to create NetworkBusWrapper!")

		# Initialize managers, passing the network wrapper
		avatar_manager = AvatarServerManager.new(network_bus)
		if avatar_manager:
			add_child(avatar_manager)
		else:
			printerr("WorldServer '", world_id, "': Failed to create AvatarServerManager!")
			
		battle_manager = BattleServerManager.new()
		if battle_manager:
			add_child(battle_manager)
		else:
			printerr("WorldServer '", world_id, "': Failed to create BattleServerManager!")

	# Adds a client to this world. Creates their avatar and sends initial state.
	# Returns true if successful, false otherwise.
	func add_client(client: Server.ClientBase) -> bool:
		if not client:
			printerr("World '", world_id, "': Attempted to add invalid client instance.")
			return false
		if client.id == "":
			printerr("World '", world_id, "': Attempted to add client with no ID.")
			return false
		if client.id in network_bus.connected_clients:
			printerr("World '", world_id, "': Client '", client.id, "' is already in this world.")
			# Update client's world ID just in case it was inconsistent
			client.current_world_id = world_id
			return true # Idempotent: Already here, consider it success.

		if not avatar_manager:
			printerr("World '", world_id, "': Cannot add client '", client.id, "', Avatar Manager is invalid.")
			client.force_disconnect("Server error: World avatar manager unavailable.")
			return false

		# 1. Create the server-side avatar state for this client.
		var avatar_state: AvatarServerManager.AvatarServerState = avatar_manager.create_avatar(client.id, client.username, client.color)
		if not avatar_state:
			printerr("World '", world_id, "': Failed to create avatar for client '", client.id, "'.")
			client.force_disconnect("Server error: Failed to create avatar.")
			return false

		# 2. Update client's routing information.
		client.current_world_id = world_id
		client.controlled_avatar_id = avatar_state.avatar_id
		# Ensure battle ID is cleared when entering a new world
		client.current_battle_id = ""

		# 3. Add client to this world's network bus list.
		network_bus.add_client(client.id)

		# 4. Send initial world state and local avatar ID to the joining client.
		network_bus.send_data(client.id, "world_init", [avatar_state.avatar_id, serialize()])

		# 5. Broadcast the new avatar's state *and* existing avatar states to the joining client *and* others.
		# Send full state update to ensure everyone is synchronized.
		var all_avatar_states := {}
		for existing_avatar_id: String in avatar_manager.avatars:
			var existing_state: AvatarServerManager.AvatarServerState = avatar_manager.avatars[existing_avatar_id]
			all_avatar_states[existing_avatar_id] = existing_state.serialize()
			# Mark existing avatars as needing update if the flag wasn't set, so they get resent.
			# existing_state.needs_state_update = true # Can cause redundant sends, but ensures sync. Let _process handle normal updates.
		
		if not all_avatar_states.is_empty():
			# Broadcast to everyone currently in this world (including the new client).
			network_bus.broadcast_data("avatar_state_update", [all_avatar_states])
		
		print("World '", world_id, "': Client '", client.id, "' added successfully.")
		return true


	# Removes a client from this world, cleaning up their avatar and network state.
	func remove_client(client: Server.ClientBase) -> void:
		if not client:
			printerr("World '", world_id, "': Attempted to remove invalid client instance.")
			return
		if client.id == "":
			printerr("World '", world_id, "': Attempted to remove client with no ID.")
			return
		if network_bus == null:
			return
		if client.id not in network_bus.connected_clients:
			# printerr("World '", world_id, "': Client '", client.id, "' not found in this world for removal.")
			# Clear potentially stale IDs on client object anyway
			if client.current_world_id == world_id: client.current_world_id = ""
			if client.controlled_avatar_id != "": client.controlled_avatar_id = ""
			# If they were in a battle in this world, that needs checking too? Risky.
			return

		print("World '", world_id, "': Removing client '", client.id, "'...")

		# 1. Remove avatar (this also broadcasts despawn message via avatar_manager).
		if avatar_manager:
			avatar_manager.remove_avatar_for_client(client.id)
		else:
			printerr("World '", world_id, "': Avatar manager invalid during client removal for '", client.id, "'. Avatar might linger.")

		# 2. Clear client's routing info related to this world.
		# Check if they still think they are in this world before clearing.
		if client.current_world_id == world_id:
			client.current_world_id = ""
			client.controlled_avatar_id = "" # Should have been cleared by avatar removal implicitly? Redundant is safe.
		
		# 3. If client was in a battle within this world, remove them.
		if client.current_battle_id != "":
			if battle_manager:
				var battle: BattleLogic = battle_manager.get_battle(client.current_battle_id)
				if battle:
					battle.remove_player(client.id)
				else:
					printerr("World '", world_id, "': Client '", client.id,"' was in battle '", client.current_battle_id,"' but battle instance is invalid.")
			else:
				printerr("World '", world_id, "': Battle manager invalid during client removal for '", client.id, "'. Cannot remove from battle.")
			# Clear battle ID regardless of whether removal succeeded.
			client.current_battle_id = ""

		# 4. Remove client from this world's network bus list.
		network_bus.remove_client(client.id)

	# Serializes the static state of the world itself (e.g., name, environment).
	# Used when sending 'world_init'.
	func serialize() -> Dictionary:
		return {
			World.KEYS.WORLD_NAME: world_id
			# Add other world properties: time of day, weather, etc.
		}

	# Clean up when the world node is removed.
	func _exit_tree() -> void:
		print("WorldServer '", world_id, "' exiting tree.")
		# Managers added as children should be freed automatically.
		# RefCounted objects like NetworkBusWrapper need references dropped.
		network_bus = null


# --- WorldServerManager Main Logic ---

# Reference to the main server network bus for communication outside worlds.
var network_bus: Server.NetworkBus

# Dictionary storing active world instances, keyed by world ID.
var worlds: Dictionary[String, WorldServer] = {}

# Initialization requires the main server network bus.
func _init(main_network_bus: Server.NetworkBus) -> void:
	name = "WorldServerManager"
	if not main_network_bus: # Check valid object
		printerr("WorldServerManager._init(): Main network bus instance is null!")
	network_bus = main_network_bus


# Finds a random active world. Optionally avoids a specific world ID.
# Returns a WorldServer instance or null if none are available/valid.
func get_random_world(avoid_world_id: String = "") -> WorldServer:
	var available_world_keys: Array[String] = worlds.keys()
	
	if available_world_keys.is_empty():
		printerr("WorldServerManager: No worlds loaded to choose from.")
		return null

	if available_world_keys.size() == 1 and available_world_keys[0] == avoid_world_id:
		printerr("WorldServerManager: Only one world ('", avoid_world_id,"') exists, cannot pick a different one.")
		# Return the only world available in this case? Or null? Let's return null.
		return null
		
	var chosen_world_id: String
	# Simple random pick logic
	if avoid_world_id == "" or available_world_keys.size() == 1:
		chosen_world_id = available_world_keys.pick_random()
	else:
		# Try picking until we get one different from avoid_world_id
		var attempts := 0
		chosen_world_id = available_world_keys.pick_random()
		while chosen_world_id == avoid_world_id and attempts < 10: # Prevent infinite loop
			chosen_world_id = available_world_keys.pick_random()
			attempts += 1
		
		# If we still landed on the same world, manually pick the first one that isn't avoid_world_id
		if chosen_world_id == avoid_world_id:
			for key in available_world_keys:
				if key != avoid_world_id:
					chosen_world_id = key
					break
					
	if not worlds.has(chosen_world_id): # Should not happen if logic is correct
		printerr("WorldServerManager: Random selection resulted in unknown world ID '", chosen_world_id, "'.")
		return null
		
	var world_instance: WorldServer = worlds[chosen_world_id]
	if not world_instance:
		printerr("WorldServerManager: Selected world '", chosen_world_id, "' instance is invalid.")
		# Maybe remove invalid instance from dictionary here?
		worlds.erase(chosen_world_id)
		# Try finding another one recursively? Careful with stack overflow.
		return get_random_world(avoid_world_id) # Try again
		
	return world_instance


# Creates, initializes, and registers a new world instance.
func load_world(world_id: String) -> bool:
	if world_id == "":
		printerr("WorldServerManager: Attempted to load world with empty ID.")
		return false
	if world_id in worlds:
		printerr("WorldServerManager: World '", world_id, "' is already loaded.")
		return true # Consider already loaded as success

	if not network_bus:
		printerr("WorldServerManager: Cannot load world '", world_id, "', main network bus is invalid.")
		return false

	print("WorldServerManager: Loading world '", world_id, "'...")
	var world_instance := WorldServer.new(world_id, network_bus)
	if world_instance:
		# Add the world node as a child of the manager for scene tree organization.
		add_child(world_instance)
		worlds[world_id] = world_instance
		print("WorldServerManager: World '", world_id, "' loaded successfully.")
		return true
	else:
		printerr("WorldServerManager: Failed to create instance for world '", world_id, "'.")
		return false


# Unloads a world instance, cleans up its resources, and removes it.
func unload_world(world_id: String) -> void:
	if world_id in worlds:
		print("WorldServerManager: Unloading world '", world_id, "'...")
		var world_instance: WorldServer = worlds[world_id]
		worlds.erase(world_id) # Remove from dictionary first

		if world_instance:
			# TODO: Gracefully move any players currently in this world to another world first?
			# for client_id in world_instance.network_bus.connected_clients.duplicate(): # Iterate copy
			#	 if server.clients.has(client_id): # Access server via network_bus? Needs refactor
			#		 var client = server.clients[client_id]
			#		 # Find new world, call add_client, etc. - Complex logic
					 
			# Remove node from tree and free it
			if world_instance.get_parent() == self:
				remove_child(world_instance)
			world_instance.queue_free()
			print("WorldServerManager: World '", world_id, "' unloaded.")
		else:
			printerr("WorldServerManager: Instance for world '", world_id, "' was already invalid during unload.")
	else:
		printerr("WorldServerManager: Attempted to unload non-existent world '", world_id, "'.")
