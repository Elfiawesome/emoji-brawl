class_name World extends Node2D

var avatar_manager: AvatarClientManager
var network_connection: GameSession.NetworkConnectionBase

func _ready() -> void:
	avatar_manager = AvatarClientManager.new(self, network_connection)
	add_child(avatar_manager)

func deserialize(state_data: Dictionary) -> void:
	$Label.text = "World: " + state_data.get(KEY.WORLD_NAME, "Null")

const KEY = {
	WORLD_NAME = "wn"
}
