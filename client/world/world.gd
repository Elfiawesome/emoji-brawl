class_name World extends Node2D

## Represents the client-side game world environment (e.g., a map, town, area).
# Manages avatars within this world. Instantiated in _ready.
var avatar_manager: AvatarClientManager
# Reference to the main network connection for communication. Set by GameSession.
var network_connection: GameSession.NetworkConnectionBase

# Keys used for deserializing world state data.
const KEYS := {
	WORLD_NAME = "wn"
}

@onready var world_label: Label = $Label # DEBUG: Reference to the label displaying the world name.

func _ready() -> void:
	# Ensure network connection is set before initializing managers that need it.
	if not network_connection:
		printerr("World._ready(): Network connection is null. Avatar manager might not function correctly.")

	# Initialize and add the avatar manager
	avatar_manager = AvatarClientManager.new(self, network_connection)
	add_child(avatar_manager)


# Updates the world's state based on data received from the server.
# Currently only sets the world name label.
func deserialize(state_data: Dictionary) -> void:
	world_label.text = "World: " + state_data.get(KEYS.WORLD_NAME, "Unknown World")
