class_name AvatarClientManager extends Node

# Scene resource for creating new avatar instances.
const AVATAR_SCENE := preload("res://client/avatar.tscn")

# Parent world node this manager belongs to.
var world: World
# Reference to the main network connection for sending input.
var network_connection: GameSession.NetworkConnectionBase

# Dictionary storing currently active avatars, keyed by avatar_id.
var avatars: Dictionary = {} # [String, Avatar]
# ID of the avatar controlled by the local player. Used for input and prediction.
var local_avatar_id: String = ""

# Initialization requires the parent world and network connection.
func _init(parent_world: World, net_connection: GameSession.NetworkConnectionBase) -> void:
	name = "AvatarClientManager"
	world = parent_world
	network_connection = net_connection
	if !world:
		printerr("AvatarClientManager._init(): Parent world instance is not valid!")
	if !network_connection:
		printerr("AvatarClientManager._init(): Network connection object is null!")


# Called every frame. Processes local player input.
func _process(delta: float) -> void:
	_process_local_input(delta)


# Applies predicted movement locally for immediate feedback.
# This movement will be corrected later by server state updates (reconciliation).
func predict_local_avatar_movement(movement_delta: Vector2) -> void:
	if local_avatar_id != "" and local_avatar_id in avatars:
		var local_avatar: Avatar = avatars[local_avatar_id]
		if local_avatar:
			local_avatar.position += movement_delta
		else:
			# This shouldn't happen...
			printerr("predict_local_avatar_movement: Local avatar instance (ID: '", local_avatar_id, "') is invalid.")


# Sets the ID of the avatar controlled by the local player.
# Updates the 'is_local' status on the old and new local avatars.
func set_local_avatar_id(new_local_avatar_id: String) -> void:
	# Mark the old local avatar as non-local, if one existed and is still valid.
	if local_avatar_id != "" and local_avatar_id in avatars:
		var old_local_avatar: Avatar = avatars[local_avatar_id]
		if old_local_avatar:
			old_local_avatar.set_is_local(false)
		else:
			printerr("set_local_avatar_id: Old local avatar instance (ID: '", local_avatar_id, "') was invalid when trying to unset.")

	# Set the new local avatar ID
	local_avatar_id = new_local_avatar_id

	# Mark the new avatar as local, if it exists and is valid.
	if local_avatar_id != "" and local_avatar_id in avatars:
		var new_local_avatar: Avatar = avatars[local_avatar_id]
		if new_local_avatar:
			new_local_avatar.set_is_local(true)
		else:
			printerr("set_local_avatar_id: New local avatar instance (ID: '", local_avatar_id, "') is invalid.")
			local_avatar_id = "" # Reset if the new avatar is invalid
	elif local_avatar_id != "":
		# The ID was set, but the avatar doesn't exist in the dictionary.
		# Maybe when we create the avatar later, we can set the local anyways.
		pass 


# Creates and adds a new avatar instance to the world based on server data.
func spawn_avatar(avatar_id: String, initial_state: Dictionary) -> void:
	if avatar_id == "":
		printerr("spawn_avatar: Attempted to spawn avatar with empty ID.")
		return
	if avatar_id in avatars:
		printerr("spawn_avatar: Avatar with ID '", avatar_id, "' already exists. Deserializing state instead.")
		var existing_avatar : Avatar = avatars[avatar_id]
		if existing_avatar:
			existing_avatar.deserialize(initial_state)
			# Ensure position is set directly on spawn/respawn, not lerped
			existing_avatar.position = initial_state.get(Avatar.KEYS.POSITION, existing_avatar.position)
		else:
			printerr("spawn_avatar: Existing avatar instance for ID '", avatar_id, "' is invalid. Removing entry.")
			avatars.erase(avatar_id) # Clean up invalid entry before trying to spawn again below
		return

	if !world:
		printerr("spawn_avatar: Cannot spawn avatar because parent world is invalid.")
		return

	var avatar_instance: Avatar = AVATAR_SCENE.instantiate() as Avatar
	if !avatar_instance:
		printerr("spawn_avatar: Failed to instantiate AVATAR_SCENE for ID '", avatar_id, "'.")
		return

	world.add_child(avatar_instance)
	avatars[avatar_id] = avatar_instance

	# Apply initial state
	avatar_instance.deserialize(initial_state)
	# SPECIAL CASE: Set initial position directly, don't lerp from default.
	avatar_instance.position = initial_state.get(Avatar.KEYS.POSITION, avatar_instance.position)

	# If this newly spawned avatar is the local one, mark it.
	if avatar_id == local_avatar_id:
		avatar_instance.set_is_local(true)

	print("Avatar spawned: ", avatar_id)


# Removes and frees an avatar instance from the world.
func despawn_avatar(avatar_id: String) -> void:
	if avatar_id == "":
		printerr("despawn_avatar: Attempted to despawn avatar with empty ID.")
		return
		
	if avatar_id in avatars:
		var avatar_instance: Avatar = avatars[avatar_id]
		if avatar_instance:
			avatar_instance.queue_free()
		else:
			printerr("despawn_avatar: Avatar instance for ID '", avatar_id, "' was already invalid.")
		
		avatars.erase(avatar_id)
		print("Avatar despawned: ", avatar_id)

		# If the despawned avatar was the local one, clear the reference.
		if avatar_id == local_avatar_id:
			local_avatar_id = ""
			print("Local avatar was despawned.")
	else:
		printerr("despawn_avatar: Attempted to despawn non-existent avatar with ID '", avatar_id, "'.")


# Reads local input, predicts movement, and sends input data to the server.
func _process_local_input(delta: float) -> void:
	# Only process input if there's a valid local avatar and network connection.
	if local_avatar_id == "" or not local_avatar_id in avatars:
		return # No local avatar to control
	
	if not network_connection:
		return # Cannot send input

	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_direction != Vector2.ZERO:
		# 1. Predict movement locally for responsiveness.
		# Use the server's movement speed constant for consistency.
		# Note: This relies on AvatarServerManager being accessible or its constants duplicated/shared.
		# It's better to share constants via a common autoload/class if possible.
		# Assuming MOVEMENT_SPEED is globally accessible or defined here for now.
		# TODO: Refactor movement speed constant location. Using a placeholder value.
		var movement_speed : float = 300.0 # Placeholder - ideally get from a shared source
		var move_vector := input_direction.normalized() * movement_speed * delta
		predict_local_avatar_movement(move_vector)

		# 2. Send the raw input direction and delta time to the server.
		# The server will perform the authoritative movement calculation.
		network_connection.send_data("avatar_input", [input_direction, delta])
