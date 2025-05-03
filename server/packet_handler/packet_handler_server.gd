class_name PacketHandlerServer extends RefCounted
## Base class and registry for server-side packet handlers.

# Simple registry to hold instances of all packet handlers.
static var _registry := RegistrySimple.new()

# Scans the designated folder and registers all packet handler scripts found.
# Assumes handler script filename matches the packet type string (e.g., "avatar_input.gd").
static func register() -> void:
	var handler_path := "res://server/packet_handler/"
	# Instantiate handlers as they are stateless command objects.
	_registry.register_all_objects_in_folder(handler_path, RegistrySimple.InstantiationType.INSTANCE_AS_CLASS)
	print("Server Packet Handlers Registered: ", _registry.get_registries())


# Retrieves a handler instance from the registry based on packet type.
static func get_handler(packet_type: String) -> PacketHandlerServer:
	var handler: PacketHandlerServer = _registry.get_object(packet_type) as PacketHandlerServer
	if not handler:
		printerr("Server Error: No handler registered for packet type '", packet_type, "'")
	return handler


# Abstract method to be implemented by specific handlers.
# Executes the logic for a received packet from a specific client.
func run(_server: Server, _client: Server.ClientBase, _data: Array) -> void:
	printerr("Packet handler '", self.get_script().resource_path, "' does not implement run() method.")
	pass # Implement in subclasses


# Optional base validation method. Can be overridden by subclasses if needed.
# Default implementation accepts any data.
func validate_data(_data: Array) -> bool:
	return true
