extends PacketHandlerClient

func run(game: GameSession, _data: Array) -> void:
	# No data is sent by server. This is a handshake.
	game.network_connection.send_data("connection_request", [
			game.network_connection.username, 
			Color(randf(), randf(), randf())
		]
	)
