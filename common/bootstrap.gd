extends Node

func _ready() -> void:
	print("Bootstrap: Initializing...")
	register_client()
	register_server()
	print("Bootstrap: Initialization complete.")

func register_client() -> void:
	PacketHandlerClient.register()

func register_server() -> void:
	PacketHandlerServer.register()
