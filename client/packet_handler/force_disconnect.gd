extends PacketHandlerClient

func run(game: GameSession, data: Array) -> void:
	var reason := "Disconnected by server."
	if (data.size() == 1) and (data[0] is Dictionary):
		var disconnect_data: Dictionary = data[0]
		reason = disconnect_data.get("reason", reason)
	
	game.disconnect_panel.visible = true
	game.disconnect_label.text = "Disconnected\n"
	game.disconnect_label.text += reason
	game.network_connection.leave_server()
