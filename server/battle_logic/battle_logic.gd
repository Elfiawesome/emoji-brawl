class_name BattleLogic extends Node

var id: String
var players: Dictionary[String, PlayerInstance] = {}


class PlayerInstance:
	var emoji_slots: Array = []
