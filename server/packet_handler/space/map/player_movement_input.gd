extends SpacePacketHandlerServer

func scope_run_as_map(space_map: SpaceMap, client_id: String, data: Array) -> void:
	if !Schema.is_valid(data, [TYPE_VECTOR2, TYPE_FLOAT]): return
	
	if client_id in space_map._client_id_to_entity_id:
		var entity_id := space_map._client_id_to_entity_id[client_id]
		var entity := space_map.entities[entity_id]
		
		var input_dir := data[0] as Vector2
		var client_delta := data[1] as float
		var velocity := input_dir * LocalEntity.BASE_SPEED * client_delta
		entity.position += velocity
		entity.needs_state_update = true
