class_name SpaceMap extends ServerSpaceManager.ServerSpace
# Base class for an area compartmentalized into 'map' areas
# For example, a town, city, dungeon etc.

var map_id: String
var entities: Dictionary[String, EntityState] = {}
var _client_id_to_entity_id: Dictionary[String, String] = {} # Used when we want to move a player's entity and delete a player's entity

# Map state
var player_data: Dictionary[String, Dictionary] = {} # [client_id, entity state data]
var map_name: String # Visual Name
var map_description: String

func _init(map_id_: String, map_data: Dictionary) -> void:
	map_id = map_id_
	load_state(map_data)

func _process(_delta: float) -> void:
	var snapshot := get_entities_snapshot()
	if !snapshot.is_empty():
		broadcast_data("entities_snapshot", [snapshot])

func client_joined(client_id: String) -> void:
	super.client_joined(client_id)
	
	# Create entity and store inside map
	var entity_state := spawn_entity()
	_client_id_to_entity_id[client_id] = entity_state.id
	
	entity_state.position = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	
	# Load player_data data if he's been here before
	if client_id in player_data:
		entity_state.from_entity_data(player_data[client_id])
	
	send_data(client_id, "spawn_map", [entity_state.id, map_name, map_description])
	broadcast_data("entities_snapshot", [get_entities_snapshot(true)])

func client_left(client_id: String) -> void:
	super.client_left(client_id)
	
	if client_id in _client_id_to_entity_id:
		var entity_id := _client_id_to_entity_id[client_id]
		var entity := entities[entity_id]
		
		# save into player_data
		player_data[client_id] = entity.to_entity_data()
		
		despawn_entity(entity_id)
		_client_id_to_entity_id.erase(client_id)
		broadcast_data("despawn_entity", [entity_id])


func spawn_entity() -> EntityState:
	var entity := EntityState.new()
	var entity_id := UUID.v4()
	entities[entity_id] = entity
	entity.id = entity_id
	return entity

func despawn_entity(entity_id: String) -> void:
	if entities.has(entity_id):
		entities.erase(entity_id)

func get_entities_snapshot(include_all: bool = false) -> Dictionary:
	var snapshot: Dictionary = {}
	for entity_id in entities:
		var entity := entities[entity_id]
		if entity.needs_state_update or include_all:
			snapshot[entity_id] = entity.serialize()
			entity.needs_state_update = false
	return snapshot

func load_state(_map_data: Dictionary) -> void:
	map_name = _map_data.get("name", "ID_" + map_id)
	map_description = _map_data.get("description", "")
	
	for client_id: String in _map_data.get("player_data", []):
		player_data[client_id] = _map_data["player_data"][client_id]

func save_state() -> Dictionary:
	# Serialize leftover player's as well
	for client_id in _client_id_to_entity_id:
		var entity_id := _client_id_to_entity_id[client_id]
		var entity := entities[entity_id]
		player_data[client_id] = entity.to_entity_data()
	return {
		"map_id": map_id,
		"name": map_name,
		"description": map_description,
		"player_data": player_data
	}

class EntityState:
	var id: String
	
	var position: Vector2
	var needs_state_update: bool = false
	
	# NOTE use serialize if we are going to sent it through put_var
	# NOTE use to_xxx_data/to_data if we are going to sent it through json
	# NOTE THis concept is still pretty messy
	func serialize() -> Dictionary:
		return { "position": position }
	
	func to_entity_data() -> Dictionary:
		return {"position": [position.x, position.y]}
	
	func from_entity_data(data: Dictionary) -> void:
		var _p: Array = data.get("position", [0, 0])
		position = Vector2(_p[0], _p[1])
	
