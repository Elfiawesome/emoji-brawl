extends PacketHandlerClient

const DEFAULT_REASON: String = "Disconnected by server."

# Displays the disconnect panel with a reason and triggers local disconnection logic.
func run(game: GameSession, data: Array) -> void:
	var reason := DEFAULT_REASON
	
	# Try to parse the reason from data if provided correctly
	if data.size() == 1 and data[0] is Dictionary:
		var disconnect_data: Dictionary = data[0]
		reason = disconnect_data.get("reason", DEFAULT_REASON)
		# Ensure reason is actually a string
		if not reason is String:
			printerr("'force_disconnect': Reason provided was not a string, using default. Got: ", typeof(reason))
			reason = DEFAULT_REASON
	elif data.size() > 0:
		printerr("'force_disconnect': Received unexpected data format. Data: ", data)
		# Stick with default reason

	game.disconnect_panel.visible = true
	game.disconnect_label.text = "Disconnected\n" + reason

	if game.network_connection:
		game.network_connection.leave_server()
	else:
		printerr("'force_disconnect': Network connection instance is not valid.")