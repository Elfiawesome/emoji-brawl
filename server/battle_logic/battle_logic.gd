## Represents the server-side logic and state for a single battle instance.
class_name BattleLogic extends Node # Changed from RefCounted to Node for potential scene tree integration

# Unique identifier for this battle instance.
var id: String = ""

# Dictionary mapping player IDs (e.g., client ID or a battle-specific ID) to their state within this battle.
var players: Dictionary[String, PlayerInstance] = {}

# Represents the state of a single player within this battle.
# Extend this class with battle-specific player data (HP, status, deck, etc.)
class PlayerInstance extends RefCounted: # Use RefCounted for state objects not in scene tree
	var client_id: String # Link back to the Server.ClientBase id
	var avatar_id: String # Link back to the AvatarServerState id
	var health: int = 100
	var energy: int = 3
	var emoji_slots: Array = [] # Example state: Array of equipped emojis/skills
	# Add other battle-relevant state variables here

	func _init(p_client_id: String, p_avatar_id: String) -> void:
		client_id = p_client_id
		avatar_id = p_avatar_id

# Called when the Node is added to the scene tree (if applicable).
# Use this for initialization that depends on the node structure.
# func _ready() -> void:
#	pass

# Add a player (client) to this battle instance.
func add_player(client: Server.ClientBase) -> bool:
	if !client:
		printerr("BattleLogic.add_player (", id, "): Invalid client provided.")
		return false
	if client.id in players:
		printerr("BattleLogic.add_player (", id, "): Client '", client.id, "' is already in this battle.")
		return false # Or maybe return true if idempotent behaviour is desired?

	var player_instance := PlayerInstance.new(client.id, client.controlled_avatar_id)
	if not player_instance:
		printerr("BattleLogic.add_player (", id, "): Failed to create PlayerInstance for client '", client.id, "'.")
		return false
		
	players[client.id] = player_instance
	print("BattleLogic (", id, "): Player '", client.id, "' added.")
	# Potentially send initial battle state update to this player or all players
	return true

# Remove a player from the battle (e.g., on disconnect or leaving battle).
func remove_player(client_id: String) -> void:
	if client_id in players:
		var player_instance: PlayerInstance = players[client_id]
		players.erase(client_id)
		print("BattleLogic (", id, "): Player '", client_id, "' removed.")
		# PlayerInstance (RefCounted) should be freed automatically if no other refs exist.
		# Handle game logic implications (e.g., end battle if opponent leaves).
	else:
		printerr("BattleLogic.remove_player (", id, "): Player '", client_id, "' not found in this battle.")


# Returns the current state of the battle, suitable for sending to clients.
func serialize() -> Dictionary:
	var serialized_players := {}
	for p_id in players:
		var p_instance: PlayerInstance = players[p_id]
		# Add serialization logic to PlayerInstance if needed
		serialized_players[p_id] = {
			"hp": p_instance.health,
			"energy": p_instance.energy,
			"emojis": p_instance.emoji_slots.duplicate() # Send copy
		}
		
	return {
		"battle_id": id,
		"players": serialized_players,
		# Add other battle state: current turn, environment effects, etc.
	}