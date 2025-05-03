class_name BattleServerManager extends Node

var battles: Dictionary[String, BattleLogic] = {}

func create_battle() -> BattleLogic:
	var battle := BattleLogic.new()
	battle.id = UUID.v4()
	battles[battle.id] = battle
	return battle
