class_name AvatarServerManager extends Node

# Constants
const DEFAULT_START_POS := Vector2(200, 200)
const MOVEMENT_SPEED := 300.0

# Reference of a wrapper
var network_bus: WorldServerManager.WorldServer.NetworkBusWrapper

# Game states
var avatars: Dictionary[String, AvatarServerState] = {}
var _client_to_avatar: Dictionary[String, String] = {} # Map of clients id to avatar id

func _init(network_bus_: WorldServerManager.WorldServer.NetworkBusWrapper) -> void:
	name = "AvatarServerManager"
	network_bus = network_bus_

func create_avatar(client_id: String, username: String) -> AvatarServerState:
	if client_id in _client_to_avatar:
		push_warning("Client %s already has an avatar." % client_id)
		return avatars[_client_to_avatar[client_id]]
	
	var avatar_id := UUID.v4()
	var start_pos := DEFAULT_START_POS
	var new_avatar_state := AvatarServerState.new(avatar_id, start_pos)
	new_avatar_state.username = username
	
	avatars[avatar_id] = new_avatar_state
	_client_to_avatar[client_id] = avatar_id
	print("Avatar %s created for client %s" % [avatar_id, client_id])
	
	# Mark for initial broadcast
	new_avatar_state.need_update_state = true
	
	return new_avatar_state

func _process(_delta: float) -> void:
	send_state_updates()

func remove_avatar_for_client(client_id: String) -> void:
	# TODO: is it really neccesary for _client_to_avatar?
	if client_id in _client_to_avatar:
		var avatar_id := _client_to_avatar[client_id]
		if avatar_id in avatars:
			print("Removing avatar %s for client %s" % [avatar_id, client_id])
			avatars.erase(avatar_id) # Remove AvatarServerState + auto cleanup since RefCounted
			network_bus.broadcast_specific_data([client_id], "avatar_despawned", [avatar_id], true)
		else:
			push_warning("Avatar %s not found for client %s during removal." % [avatar_id, client_id])
		_client_to_avatar.erase(client_id)
	else:
		push_warning("Client %s not found in avatar mapping during removal." % client_id)

func process_input(avatar_id: String, input_direction: Vector2, delta: float) -> void:
	if avatar_id in avatars:
		var state := avatars[avatar_id]
		if input_direction != Vector2.ZERO:
			state.position += input_direction.normalized() * MOVEMENT_SPEED * delta
			state.need_update_state = true
	else:
		push_warning("Received input for unknown avatar_id: %s" % avatar_id)

func send_state_updates() -> void:
	var changed_states: Dictionary = {}
	for avatar_id in avatars:
		var state := avatars[avatar_id]
		if state.need_update_state:
			changed_states[avatar_id] = state.serialize()
			state.need_update_state = false # Reset flag
	
	if not changed_states.is_empty():
		# Broadcast only the changed states to all clients
		network_bus.broadcast_data("avatar_state_update", [changed_states])
		# TODO: Send only relevant states based on proximity (Area of Interest)

class AvatarServerState extends RefCounted:
	var avatar_id: String
	var position: Vector2
	var color: Color = Color.WHITE
	var username: String
	var need_update_state: bool = true
	
	func _init(avatar_id_: String, start_pos_: Vector2 = Vector2.ZERO) -> void:
		avatar_id = avatar_id_
		position = start_pos_
	
	func serialize() -> Dictionary:
		return {
			Avatar.KEYS.POSITION: position,
			Avatar.KEYS.COLOR: color,
			Avatar.KEYS.USERNAME: username
		}
