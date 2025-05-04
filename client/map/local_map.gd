class_name LocalMap extends Node2D
# Visual representation on client side of a map

const ENTITY_SCENE := preload("res://client/map/local_entity.tscn")
# TODO: REMOVElater
@onready var debug_label: Label = $Camera2D/CanvasLayer/Label

# Reference to send data
var connection: NetworkClientManager.Connection

# State
var entities: Dictionary[String, LocalEntity] = {}
var local_entity_id: String # The entity that I will be controlling

func _ready() -> void:
	# TODO: Custom Map loading
	var tile_map_layer: TileMapLayer = $TileMapLayer/Base
	var data: Dictionary = JSON.parse_string(FileAccess.open("res://asset/tileset/willow.json", FileAccess.READ).get_as_text()) as Dictionary
	
	var _tile_size: PackedInt32Array = data.get("tile_size")
	var tile_size := Vector2i(_tile_size[0], _tile_size[1])
	var tile_types: Dictionary = data.get("tiles")
	var texture_path: String = data.get("texture")
	var loaded_texture := load("res://asset/tileset/" + texture_path)
	
	var tile_set_source := TileSetAtlasSource.new()
	tile_set_source.texture = loaded_texture
	
	for tile_type: String in tile_types:
		var _tile_coords: PackedInt32Array = tile_types[tile_type]
		var tile_coords := Vector2i(_tile_coords[0], _tile_coords[1])
		tile_set_source.create_tile(tile_coords)
		tile_set_source.set_tile_animation_columns(tile_coords, 3)
	
	
	var tile_set := TileSet.new()
	tile_set.tile_size = tile_size
	tile_set.add_source(tile_set_source, 0)
	
	
	tile_map_layer.tile_set = tile_set
	for i in 100:
		for ii in 100:
			tile_map_layer.set_cell(Vector2i(i,ii), 0, Vector2(randi_range(0, 3), randi_range(0,0)))

func spawn_entity(entity_id: String, initial_state: Dictionary) -> LocalEntity:
	var entity: LocalEntity = ENTITY_SCENE.instantiate()
	entities[entity_id] = entity
	add_child(entity)
	entity.deserialize(initial_state)
	# NOTE: Special case, I want the position to immediately update regardless if its local or not
	entity.position = entity.target_position
	if entity_id == local_entity_id:
		set_local_entity_id(entity_id)
	return entity

func despawn_entity(entity_id: String) -> void:
	if entities.has(entity_id):
		var entity := entities[entity_id]
		entity.queue_free()
		entities.erase(entity_id)

func set_local_entity_id(new_id: String) -> void:
	if local_entity_id:
		if local_entity_id in entities:
			entities[local_entity_id]._is_local = false
	# Just set the local entity first. Wait till entity is created later then we set his _is_local
	local_entity_id = new_id
	if new_id in entities:
		entities[new_id]._is_local = true


## Input TODO:  need put elsewhere
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		connection.send_data("player_map_travel")

func _process(delta: float) -> void:
	# TODO: I have to put the controls somewhere...
	if !local_entity_id: return # No entity to control
	
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_direction != Vector2.ZERO:
		var move_vector := input_direction.normalized() * LocalEntity.BASE_SPEED * delta
		predict_local_avatar_movement(move_vector)
		
		connection.send_data("player_movement_input", [input_direction, delta])

func predict_local_avatar_movement(move: Vector2) -> void:
	# Apply movement directly to local avatar for responsiveness
	if (local_entity_id) and (local_entity_id in entities):
		var local_entity := entities[local_entity_id]
		local_entity.position += move
