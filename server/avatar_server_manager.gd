class_name AvatarServerManager extends Node
## Manages server-side avatar state and logic within a specific world instance.
## Handles creation, removal, input processing, and state synchronization.

## Represents the authoritative state of an avatar on the server.
class AvatarServerState extends RefCounted:
	var avatar_id: String          # Unique ID for this avatar.
	var client_id: String          # ID of the client controlling this avatar.
	var username: String           # Display name.
	var position: Vector2          # Current authoritative position.
	var color: Color = Color.WHITE # Avatar tint color.
	var needs_state_update: bool = true # Flag: Does client need the latest state?

	func _init(p_avatar_id: String, p_client_id: String, p_username: String, start_pos: Vector2 = Vector2.ZERO) -> void:
		avatar_id = p_avatar_id
		client_id = p_client_id
		username = p_username
		position = start_pos

	# Serializes the avatar's state into a dictionary for network transmission.
	# Uses keys defined in the client-side Avatar class for consistency.
	func serialize() -> Dictionary:
		return {
			Avatar.KEYS.POSITION: position,
			Avatar.KEYS.COLOR: color,
			Avatar.KEYS.USERNAME: username,
			# Add other state variables here if needed (e.g., health, status)
		}

# --- Constants ---
const DEFAULT_START_POS := Vector2(200, 200) # Default spawn position.
const MOVEMENT_SPEED: float = 300.0         # Movement speed in units per second.

# --- Dependencies ---
# Reference to the world-specific network bus wrapper for sending data.
var network_bus: WorldServerManager.WorldServer.NetworkBusWrapper

# --- Game State ---
# Dictionary storing active avatar states, keyed by avatar_id.
var avatars: Dictionary[String, AvatarServerState] = {}
# Reverse map for quick lookup: client_id -> avatar_id.
var _client_to_avatar: Dictionary[String, String] = {}

# Initialization requires the network bus wrapper.
func _init(net_bus_wrapper: WorldServerManager.WorldServer.NetworkBusWrapper) -> void:
	name = "AvatarServerManager"
	if not net_bus_wrapper:
		printerr("AvatarServerManager._init(): NetworkBusWrapper instance is null!")
		# This is likely a critical error.
	network_bus = net_bus_wrapper


# Called every frame by the parent WorldServer. Sends state updates.
func _process(_delta: float) -> void:
	_send_state_updates()


# Creates a new avatar state associated with a client.
# Returns the newly created state object or null on failure.
func create_avatar(client_id: String, username: String, initial_color: Color) -> AvatarServerState:
	if client_id == "":
		printerr("create_avatar: Attempted to create avatar for empty client_id.")
		return null
	if client_id in _client_to_avatar:
		var existing_avatar_id: String = _client_to_avatar[client_id]
		printerr("create_avatar: Client '", client_id, "' already has an avatar (ID: '", existing_avatar_id, "'). Returning existing.")
		if avatars.has(existing_avatar_id):
			return avatars[existing_avatar_id]
		else:
			printerr("create_avatar: Client '", client_id, "' mapping points to non-existent avatar '", existing_avatar_id,"'. State inconsistency!")
			_client_to_avatar.erase(client_id) # Clean up bad mapping
			# Fall through to create a new one.
			
	var avatar_id := UUID.v4()
	# TODO: Add logic to ensure start position doesn't collide immediately?
	var start_pos := DEFAULT_START_POS

	var new_avatar_state := AvatarServerState.new(avatar_id, client_id, username, start_pos)
	if not new_avatar_state:
		printerr("create_avatar: Failed to instantiate AvatarServerState for client '", client_id, "'.")
		return null

	new_avatar_state.color = initial_color
	
	avatars[avatar_id] = new_avatar_state
	_client_to_avatar[client_id] = avatar_id
	print("Avatar '", avatar_id, "' created for client '", client_id, "' (", username, ")")

	# Mark for initial broadcast (already true by default, but explicit)
	new_avatar_state.needs_state_update = true

	return new_avatar_state


# Removes the avatar associated with a specific client ID.
# Informs other clients in the world about the despawn.
func remove_avatar_for_client(client_id: String) -> void:
	if client_id == "":
		printerr("remove_avatar_for_client: Attempted removal for empty client_id.")
		return
		
	if client_id in _client_to_avatar:
		var avatar_id: String = _client_to_avatar[client_id]
		if avatar_id in avatars:
			print("Removing avatar '", avatar_id, "' for client '", client_id, "'")
			avatars.erase(avatar_id) # Remove state object (RefCounted, should auto-free)
			
			# Notify other clients in this world that the avatar despawned
			if network_bus:
				# Broadcast to everyone *except* the client being removed (if they are still in the list)
				# The wrapper's broadcast_specific_data with inverted=true is suitable here.
				# However, the client is already disconnected or being removed, so a normal broadcast is fine.
				network_bus.broadcast_specific_data([client_id], "avatar_despawned", [avatar_id], true)
			else:
				printerr("remove_avatar_for_client: Network bus invalid, cannot broadcast despawn.")
		else:
			printerr("remove_avatar_for_client: Avatar '", avatar_id, "' not found in avatars dictionary for client '", client_id, "' during removal.")
			
		_client_to_avatar.erase(client_id) # Remove mapping
	else:
		printerr("remove_avatar_for_client: Client '", client_id, "' not found in client-to-avatar mapping during removal.")


# Processes movement input received from a client for their avatar.
# Updates the authoritative position and flags the state for network update.
func process_input(avatar_id: String, input_direction: Vector2, delta: float) -> void:
	if avatar_id == "":
		printerr("process_input: Received input for empty avatar_id.")
		return
		
	if avatar_id in avatars:
		var state: AvatarServerState = avatars[avatar_id]
		
		# Basic input validation/sanitization
		if not input_direction.is_normalized() and input_direction != Vector2.ZERO:
			# Client should send normalized, but normalize here just in case.
			# printerr("process_input: Received non-normalized input direction from client '", state.client_id, "'. Normalizing.")
			input_direction = input_direction.normalized()
			
		if delta <= 0:
			printerr("process_input: Received invalid delta time (<= 0) from client '", state.client_id, "': ", delta)
			return # Ignore input with invalid delta

		# Apply movement based on input
		if input_direction != Vector2.ZERO:
			# Calculate movement delta based on server constants
			var move_delta := input_direction * MOVEMENT_SPEED * delta
			state.position += move_delta
			# Optional: Add server-side collision detection/physics here
			state.needs_state_update = true # Flag that state changed and needs sync
	else:
		printerr("process_input: Received input for unknown avatar_id: '", avatar_id, "'")


# Collects states of avatars that have changed and broadcasts them to clients in the world.
func _send_state_updates() -> void:
	if not network_bus:
		# printerr("_send_state_updates: Network bus is invalid. Cannot send updates.")
		# Reduce log spam: only print if there were changes to send.
		var has_changes : bool = false
		for avatar_id in avatars:
			if avatars[avatar_id].needs_state_update:
				has_changes = true
				break
		if has_changes:
			printerr("_send_state_updates: Network bus is invalid. Cannot send updates.")
		return

	var changed_states: Dictionary = {}
	for avatar_id: String in avatars:
		var state: AvatarServerState = avatars[avatar_id]
		if state.needs_state_update:
			changed_states[avatar_id] = state.serialize()
			state.needs_state_update = false # Reset flag after collecting state

	if not changed_states.is_empty():
		# Broadcast only the changed states to all clients *in this world*.
		network_bus.broadcast_data("avatar_state_update", [changed_states])
		# TODO: Implement Area of Interest (AoI) optimization:
		# Send only relevant states based on proximity/visibility to each client.
		# This would involve iterating clients and calculating relevance per client.

# Retrieves the AvatarServerState for a given client ID, if one exists.
func get_avatar_state_for_client(client_id: String) -> AvatarServerState:
	if client_id in _client_to_avatar:
		var avatar_id := _client_to_avatar[client_id]
		if avatar_id in avatars:
			return avatars[avatar_id]
	return null

# Retrieves the AvatarServerState for a given avatar ID, if one exists.
func get_avatar_state(avatar_id: String) -> AvatarServerState:
	return avatars.get(avatar_id, null)
