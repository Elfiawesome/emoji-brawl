class_name ServerSpaceManager extends Node

signal space_created(space: ServerSpace) # Not used
signal space_freed(space: ServerSpace)

var network_bus: NetworkServerManager.NetworkBus

# Spaces
var spaces: Dictionary[String, ServerSpace] = {}
var _client_to_spaces: Dictionary[String, String] = {} # [client_id, space_id] Map of clients to their assigned spaces

# Spaces > Maps
var maps_loaded: Dictionary[String, String] # [map_id, space_id]

# Add a custom server-space like map or battle into the game
func add_space(space: ServerSpace) -> void:
	var space_id := UUID.v4()
	spaces[space_id] = space
	space.id = space_id
	# Spaces sent signal packets up while server sents network_bus down
	space.data_sent.connect(network_bus.send_data)
	space_created.emit(space)
	add_child(space)

func remove_space(space_id: String) -> void:
	if space_id in spaces:
		var space := spaces[space_id]
		for client_id in space.connected_clients:
			deassign_client_from_space(client_id)
		space.queue_free()
		spaces.erase(space_id)

func assign_client_to_space(client_id: String, space_id: String) -> void:
	if client_id in _client_to_spaces:
		deassign_client_from_space(client_id)
	
	if space_id in spaces:
		spaces[space_id].client_joined(client_id)
		_client_to_spaces[client_id] = space_id

func deassign_client_from_space(client_id: String) -> void:
	if client_id in _client_to_spaces:
		var old_space_id := _client_to_spaces[client_id]
		_client_to_spaces.erase(client_id)
		if old_space_id in spaces:
			spaces[old_space_id].client_left(client_id)
			
			# delete space when empty
			if spaces[old_space_id].connected_clients.is_empty():
				space_freed.emit(spaces[old_space_id])
				remove_space(old_space_id)

class ServerSpace extends Node:
	# Generic server space class to represent a compartment in the server
	
	signal data_sent(client_id: String, type: String, data: Array)
	
	var id: String
	var connected_clients: Array[String] = []
	
	func client_joined(client_id: String) -> void:
		if !(client_id in connected_clients):
			connected_clients.push_back(client_id)
	
	func client_left(client_id: String) -> void:
		if (client_id in connected_clients):
			connected_clients.erase(client_id)
	
	func send_data(client_id: String, type: String, data: Array = []) -> void:
		data_sent.emit(client_id, type, data)
	
	func broadcast_data(type: String, data: Array = []) -> void:
		for client_id: String in connected_clients:
			send_data(client_id, type, data)
	
	func broadcast_data_specific(client_list: Array, type: String, data: Array = [], is_exclude: bool = false) -> void:
		if !is_exclude:
			for client_id: String in client_list:
				send_data(client_id, type, data)
		else:
			for client_id: String in connected_clients:
				if !(client_id in client_list):
					send_data(client_id, type, data)
