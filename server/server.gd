class_name Server extends Node

@onready var space_manager: ServerSpaceManager = $ServerSpaceManager
@onready var network_manager: NetworkServerManager = $NetworkServerManager
@onready var save_manager: SaveManager = $SaveManager

var global_player_states: Dictionary[String, PlayerState] = {} # Hold any global data from a player. Persistance globally

func _ready() -> void:
	# initialize managers
	space_manager.network_bus = network_manager.network_bus
	# Open my save
	save_manager.new_save("my_save")
	
	# Spin up the server
	network_manager.start_server(save_manager.config.address, save_manager.config.port)
	network_manager.packet_received.connect(_on_packet_received)

# Get map from save and loads into memory
func load_map(map_id: String) -> void:
	if map_id in space_manager.maps_loaded: return
	var space_map := SpaceMap.new(map_id, save_manager.load_map_state(map_id))
	space_manager.add_space(space_map)
	space_manager.maps_loaded[map_id] = space_map.id
	space_map.name = "MAP_"+map_id.to_upper()

func unload_map(map_id: String) -> void:
	if map_id in space_manager.maps_loaded:
		var space_map_id:= space_manager.maps_loaded[map_id]
		var space_map := space_manager.spaces[space_map_id] as SpaceMap
		space_manager.remove_space(space_map.id)
		space_manager.maps_loaded.erase(map_id)
		# save map state
		save_manager.save_map_state(map_id, space_map.save_state())


# Load player state into memory
func create_player_state(client_id: String) -> void:
	var player_data := save_manager.load_global_player_data(client_id)
	print(player_data)
	global_player_states[client_id] = PlayerState.new()
	global_player_states[client_id].from_data(player_data)

# unload player state from memory
func delete_player_state(client_id: String) -> void:
	if client_id in global_player_states:
		var player_data := global_player_states[client_id].to_data()
		save_manager.save_global_player_data(client_id, player_data)
		global_player_states.erase(client_id)

func shutdown() -> void:
	print("[SERVER] Shutting down...")
	# disconnect all spaces
	for space_id in space_manager.spaces:
		var space := space_manager.spaces[space_id]
		if space is SpaceMap:
			unload_map(space.map_id)
			continue
		space_manager.remove_space(space_id)
	
	# Save global player state
	for client_id in global_player_states:
		delete_player_state(client_id)

func _on_packet_received(type: String, data: Array, conn: NetworkServerManager.Connection) -> void:
	# NOTE: Noisy ah print
	#print("[SERVER] received from [%s] -> [%s]: %s" % [type, data, conn.id])
	var handler := PacketHandlerServer.get_handler(type)
	if handler:
		handler.run(self, data, conn)

class PlayerState:
	var player_name: String
	var player_level: float
	var last_map_id: String
	
	func to_data() -> Dictionary:
		return { "player_name": player_name, "player_level": player_level, "last_map_id": last_map_id }
	
	func from_data(data: Dictionary) -> void:
		player_name = data.get("player_name", player_name)
		player_level = data.get("player_level", player_level)
		last_map_id = data.get("last_map_id", last_map_id)
