class_name Server extends Node

@onready var space_manager: ServerSpaceManager = $ServerSpaceManager
@onready var network_manager: NetworkServerManager = $NetworkServerManager
@onready var save_manager: SaveManager = $SaveManager

func _ready() -> void:
	# initialize managers
	space_manager.network_bus = network_manager.network_bus
	# Open my save
	save_manager.new_save("my_save")
	
	# Load two maps
	for map_id: String in ["willow", "midtown", "crystal_shores"]:
		var space_map := SpaceMap.new(map_id, save_manager.load_map_state(map_id))
		space_manager.add_space(space_map)
		space_manager.maps_loaded[map_id] = space_map.id
		space_map.name = "MAP_"+map_id.to_upper()
	
	
	# Spin up the server
	network_manager.start_server(save_manager.config.address, save_manager.config.port)
	network_manager.packet_received.connect(_on_packet_received)

func shutdown() -> void:
	print("[SERVER] Shutting down...")
	# Clean up and save states
	for map_id in space_manager.maps_loaded:
		var space_id: String = space_manager.maps_loaded[map_id]
		var space := space_manager.spaces[space_id] as SpaceMap
		if !space: continue
		save_manager.save_map_state(map_id, space.save_state())

func _on_packet_received(type: String, data: Array, conn: NetworkServerManager.Connection) -> void:
	# NOTE: Noisy ah print
	#print("[SERVER] received from [%s] -> [%s]: %s" % [type, data, conn.id])
	var handler := PacketHandlerServer.get_handler(type)
	if handler:
		handler.run(self, data, conn)
