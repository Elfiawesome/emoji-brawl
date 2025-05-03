extends PacketHandlerClient

# Responds to the server's handshake by sending the 'connection_request' packet.
func run(game: GameSession, _data: Array) -> void:
	# Server sends no data with this packet type, it's just a trigger.
	if !game.network_connection:
		printerr("'init_request': Network connection is not available to send response.")
		return

	# Generate a random color for the avatar initially.
	# TODO: move color selection elsewhere for customization char or something.
	var random_color := Color(randf(), randf(), randf())

	# Send client information back to the server.
	game.network_connection.send_data("connection_request", [
		game.network_connection.username,
		random_color
	])
