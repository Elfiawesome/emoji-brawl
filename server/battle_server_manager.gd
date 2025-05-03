class_name BattleServerManager extends Node

## Manages battle instances within a specific world on the server.
## Responsible for creating, tracking, and potentially cleaning up battles.
# Dictionary storing active battle instances, keyed by battle ID.
var battles: Dictionary = {} # [String, BattleLogic]

func _init() -> void:
	name = "BattleServerManager"


# Creates a new BattleLogic instance, assigns an ID, and registers it.
# Returns the newly created battle instance or null on failure.
func create_battle() -> BattleLogic:
	var battle_instance := BattleLogic.new() # Assumes BattleLogic is a script class
	if not battle_instance:
		printerr("BattleServerManager: Failed to create new BattleLogic instance.")
		return null
		
	battle_instance.id = UUID.v4()
	battle_instance.name = "Battle-" + battle_instance.id # Set node name if added to tree
	
	# Optional: Add battle instance as a child of this manager node?
	# add_child(battle_instance)
	
	battles[battle_instance.id] = battle_instance
	print("BattleServerManager: Created battle '", battle_instance.id, "'")
	
	return battle_instance


# Removes a battle instance from the manager.
func remove_battle(battle_id: String) -> void:
	if battle_id in battles:
		var battle_instance: BattleLogic = battles[battle_id]
		print("BattleServerManager: Removing battle '", battle_id, "'")
		battles.erase(battle_id)
		
		# If the battle node was added as a child, remove and free it.
		if battle_instance and battle_instance.get_parent() == self:
			remove_child(battle_instance)
			battle_instance.queue_free()
		# If BattleLogic is RefCounted and not in tree, removing from dict might be enough.
		
	else:
		printerr("BattleServerManager: Attempted to remove non-existent battle '", battle_id, "'")


# Finds a battle instance by its ID.
func get_battle(battle_id: String) -> BattleLogic:
	return battles.get(battle_id, null) # Return null if not found


# func _process(delta: float) -> void:
	# Optional: Add logic here to periodically check for and clean up inactive/empty battles.
	# for battle_id in battles.keys():
	#	 var battle = battles[battle_id]
	#	 if battle and battle.players.is_empty(): # Check if battle is empty
	#		 print("Cleaning up empty battle: ", battle_id)
	#		 remove_battle(battle_id)
