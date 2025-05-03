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
	var battle_manager: BattleServerManager
	var network_bus: NetworkBusWrapper
	
	func _init(world_id_: String, network_bus_: Server.NetworkBus) -> void:
		world_id = world_id_
		network_bus = NetworkBusWrapper.new(network_bus_)
		avatar_manager = AvatarServerManager.new(network_bus)
		battle_manager = BattleServerManager.new()
		add_child(battle_manager)
		add_child(avatar_manager)
	
	func add_client(client: Server.ClientBase) -> void:
		if client.id in network_bus.connected_clients:
			return
		network_bus.connected_clients.push_back(client.id)
		
		# Create avatar for this player
		var avatar_state := avatar_manager.create_avatar(client.id, client.username)
		if not avatar_state:
			client.force_disconnect("Failed to create avatar on server.")
			return
		avatar_state.color = client.color
		# Set controller so when server receive from this client, we know which avatar it's talking about
		client.current_world_id = world_id
		client.controlled_avatar_id = avatar_state.avatar_id
		
		network_bus.send_data(client.id, "world_init", [avatar_state.avatar_id, serialize()])
		
		var serialized_avatar_states := {}
		for _avatar_id in avatar_manager.avatars:
			var _avatar_state := avatar_manager.avatars[_avatar_id]
			serialized_avatar_states[_avatar_id] = _avatar_state.serialize()
		network_bus.broadcast_data("avatar_state_update", [serialized_avatar_states])
	
	func remove_client(client: Server.ClientBase) -> void:
		avatar_manager.remove_avatar_for_client(client.id)
		client.current_world_id = ""
		client.controlled_avatar_id = ""
		# TODO: remove all instances of that guy in this battle
		client.current_battle_id = ""
		
		if client.id in network_bus.connected_clients:
			network_bus.connected_clients.erase(client.id)
	
	class NetworkBusWrapper:
		var _network_bus: Server.NetworkBus
		var connected_clients: Array
		func _init(network_bus_: Server.NetworkBus) -> void:
			_network_bus = network_bus_
		func broadcast_data(type: String, data: Array) -> void:
			_network_bus.broadcast_specific_data(connected_clients, type, data)
		func broadcast_specific_data(client_list: Array, type: String, data: Array, inverted: bool = false) -> void:
			if !inverted:
				for client_id: String in client_list:
					send_data(client_id, type, data)
			else:
				for client_id: String in connected_clients:
					if !(client_id in client_list):
						send_data(client_id, type, data)
		func send_data(client_id: String, type: String, data: Array) -> void:
			if client_id in connected_clients:
				_network_bus.send_data(client_id, type, data)
	
	func serialize() -> Dictionary:
		return {
			World.KEY.WORLD_NAME: world_id
		}
