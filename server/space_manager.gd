class_name SpaceManager extends Node

var bus: SpaceBus
var server_bus: Server.ServerBus

var spaces: Dictionary[String, Space] = {}
var _client_to_spaces: Dictionary[String, Space] = {} # [client_id, space_id] Map of clients to their assigned spaces

# Add a custom space
func add_space(space: Space) -> void:
	var space_id := UUID.v4()
	spaces[space_id] = space
	space.server_bus = server_bus
	space.id = space_id

func remove_space(space_id: String) -> void:
	if space_id in spaces:
		var space := spaces[space_id]
		for client_id in space.connected_clients:
			deassign_client_from_space(client_id)
		spaces[space_id].free()
		spaces.erase(space_id)

func assign_client_to_space(client_id: String, space_id: String) -> void:
	if client_id in _client_to_spaces:
		deassign_client_from_space(client_id)
	
	if space_id in spaces:
		spaces[space_id].client_joined(client_id)
		_client_to_spaces[client_id] = spaces[space_id]

func deassign_client_from_space(client_id: String) -> void:
	pass

class Space extends RefCounted:
	var id: String
	var connected_clients: Array[String] = []
	var server_bus: Server.ServerBus
	
	func client_joined(client_id: String) -> void:
		if !(client_id in connected_clients):
			connected_clients.push_back(client_id)
	
	func client_left(client_id: String) -> void:
		if (client_id in connected_clients):
			connected_clients.erase(client_id)

	# TODO Need to rename this ltr
	pass

	
class SpaceBus:
	pass
