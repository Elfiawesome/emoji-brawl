class_name WorldServerManager extends Node

# Reference
var network_bus: Server.NetworkBus

# Game states
var worlds: Dictionary[String, WorldServer] = {}

func _init(network_bus_: Server.NetworkBus) -> void:
	name = "WorldServerManager"
	network_bus = network_bus_

func get_random_world() -> WorldServer:
	return worlds[worlds.keys().pick_random()]

func load_world(world_id: String) -> void:
	if world_id in worlds:
		return
	var world := WorldServer.new(world_id, network_bus)
	world.name = "World-" + world_id
	add_child(world)
	
	worlds[world_id] = world

func unload_world(world_id: String) -> void:
	pass

class WorldServer extends Node:
	var world_id: String
	var avatar_manager: AvatarServerManager
	var network_bus: NetworkBusWrapper
	
	func _init(world_id_: String, network_bus_: Server.NetworkBus) -> void:
		world_id = world_id_
		network_bus = NetworkBusWrapper.new(network_bus_)
		avatar_manager = AvatarServerManager.new(network_bus)
		add_child(avatar_manager)
	
	func add_client_to_world(client_id: String) -> void:
		if client_id in network_bus.connected_clients:
			return
		network_bus.connected_clients.push_back(client_id)
	
	func remove_client_from_world(client_id: String) -> void:
		if client_id in network_bus.connected_clients:
			network_bus.connected_clients.erase(client_id)
	
	class NetworkBusWrapper:
		var network_bus: Server.NetworkBus
		var connected_clients: Array
		func _init(network_bus_: Server.NetworkBus) -> void:
			network_bus = network_bus_
		func broadcast_data(type: String, data: Array) -> void:
			network_bus.broadcast_specific_data(connected_clients, type, data)
		func broadcast_specific_data(client_list: Array, type: String, data: Array) -> void:
			for client_id: String in client_list:
				send_data(client_id, type, data)
		func send_data(client_id: String, type: String, data: Array) -> void:
			if client_id in connected_clients:
				network_bus.send_data(client_id, type, data)
	
	func serialize() -> Dictionary:
		return {
			World.KEY.WORLD_NAME: world_id
		}
