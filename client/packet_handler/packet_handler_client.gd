class_name PacketHandlerClient extends RefCounted

# Simple registry to hold instances of all packet handlers.
static var _registry := RegistrySimple.new()

static func register() -> void:
	var handler_path := "res://client/packet_handler/"
	_registry.register_all_objects_in_folder(handler_path, RegistrySimple.InstantiationType.INSTANCE_AS_CLASS)
	print("Client Packet Handlers Registered: ", _registry.get_registries())


# Retrieves a handler instance from the registry based on packet type.
static func get_handler(packet_type: String) -> PacketHandlerClient:
	var handler: PacketHandlerClient = _registry.get_object(packet_type) as PacketHandlerClient
	if not handler:
		printerr("Client Error: No handler registered for packet type '", packet_type, "'")
	return handler


func run(_game: GameSession, _data: Array) -> void:
	printerr("Packet handler '", self.get_script().resource_path, "' does not implement run() method.")
	pass # Implement in subclasses


func validate_data(_data: Array) -> bool:
	return true