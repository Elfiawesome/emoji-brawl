class_name GameSession extends Node

# Scene resources for instantiating world and battle.
const WORLD_SCENE := preload("res://client/world/world.tscn")
const BATTLE_SCENE := preload("res://client/battle.tscn")

# --- Network Connection ---
# Base class for different network connection types (integrated, server).
class NetworkConnectionBase extends Node:
	signal packet_received(type: String, data: Array) # Emitted when a packet arrives from the server.
	
	var username: String = "Player" # Default username, set during connection.

	func _init() -> void:
		name = "NetworkConnection" # Set node name for easier debugging.

	# Abstract methods to be implemented by subclasses.
	func connect_to_server(_address: String, _port: int, _username: String) -> void: pass
	func get_status() -> int: return -1 # Return a distinct value for base class
	func leave_server() -> void: pass
	func send_data(_type: String, _data: Array = []) -> void: pass

# --- Integrated Network Connection (Client connects to in-process Server) ---
class NetworkConnectionIntegrated extends NetworkConnectionBase:
	signal packet_sent(type: String, data: Array) # Used by the integrated server to receive data.

	var server: Server # Reference to the in-process server node.
	var client_handler: Server.ClientIntegrated # The server's representation of this client.

	func _init(server_node: Server) -> void:
		super._init()
		if !server_node:
			printerr("NetworkConnectionIntegrated: Invalid server node passed to _init.")
			return
		server = server_node

	func connect_to_server(_address: String, _port: int, user_name: String) -> void:
		if !server:
			printerr("NetworkConnectionIntegrated: Cannot connect, server instance is invalid.")
			return
		
		username = user_name
		# Create the server-side representation for this client
		client_handler = Server.ClientIntegrated.new()
		if !client_handler:
			printerr("NetworkConnectionIntegrated: Failed to create Server.ClientIntegrated instance.")
			return
			
		# Connect signals for two-way communication
		client_handler.packet_sent.connect(_on_packet_received_from_server) # Server -> Client
		self.packet_sent.connect(client_handler._on_packet_received_from_client) # Client -> Server (Connects to the *handler's* method)
		
		# Add the client handler to the server
		server.take_client_connection(client_handler)

		# Trigger the initial connection handshake (simulates server sending init_request)
		# We manually trigger the server->client path here.
		client_handler.send_data("init_request") # Server handler sends init_request to client
		print("Integrated connection established for user: ", username)


	func send_data(type: String, data: Array = []) -> void:
		if !client_handler:
			printerr("NetworkConnectionIntegrated: Cannot send data, client_handler is invalid.")
			return
		# Emit signal that the *client_handler* on the server side listens to.
		packet_sent.emit(type, data)

	# Callback when the *server's* client_handler sends data *to* this client.
	func _on_packet_received_from_server(type: String, data: Array) -> void:
		packet_received.emit(type, data)

	func leave_server() -> void:
		if !client_handler:
			# Simulate disconnection event for the server
			client_handler.force_disconnect("Client left (integrated).")
			# Break connection? Client handler should be freed by server.
			client_handler = null
		print("Integrated connection closed for user: ", username)
		# Optionally queue_free self or handle scene changes here


# --- Standard TCP Network Connection (Client connects to remote/local Server) ---
class NetworkConnectionServer extends NetworkConnectionBase:
	var _address: String
	var _port: int

	var _stream_peer: StreamPeerTCP
	var _packet_peer: PacketPeerStream

	const CONNECTION_TIMEOUT_MS : int = 5000 # Time in ms to wait for connection

	enum Status {
		DISCONNECTED,
		CONNECTING,
		CONNECTED,
		ERROR
	}
	var current_status : Status = Status.DISCONNECTED

	func _init() -> void:
		super._init()
		_stream_peer = StreamPeerTCP.new()
		_packet_peer = PacketPeerStream.new()
		_packet_peer.stream_peer = _stream_peer

	func connect_to_server(address: String, port: int, user_name: String) -> void:
		if current_status != Status.DISCONNECTED:
			printerr("NetworkConnectionServer: Already connected or connecting.")
			return

		_address = address
		_port = port
		username = user_name
		current_status = Status.CONNECTING

		print("Attempting to connect to ", _address, ":", _port, " as ", username)
		var err: Error = _stream_peer.connect_to_host(_address, _port)

		if err != OK:
			printerr("NetworkConnectionServer: Failed to initiate connection. Error code: ", err)
			current_status = Status.ERROR
			_report_disconnection("Connection initiation failed.")
			return

		# Status will update in _process

	func get_status() -> int:
		# Map internal enum to Godot's StreamPeerTCP status for compatibility if needed,
		# but using our own enum might be clearer. Return our enum value.
		return current_status

	func leave_server() -> void:
		if current_status != Status.DISCONNECTED:
			print("Disconnecting from server.")
			_stream_peer.disconnect_from_host()
			current_status = Status.DISCONNECTED
			# Don't queue_free immediately, allow pending packets/cleanup.
			# Consider a small delay or handling in _process after status changes.

	# Internal function to handle actual disconnection logic and signal emission.
	func _report_disconnection(reason: String = "Connection lost.") -> void:
		if current_status == Status.DISCONNECTED: return # Avoid duplicate signals

		printerr("NetworkConnectionServer: Disconnected. Reason: ", reason)
		current_status = Status.DISCONNECTED
		var disconnect_data := {"reason": reason}
		# Simulate force disconnect packet
		packet_received.emit("force_disconnect", [disconnect_data])
		# Cleanup peers
		_stream_peer = null
		_packet_peer = null


	func send_data(type: String, data: Array = []) -> void:
		if current_status != Status.CONNECTED:
			printerr("NetworkConnectionServer: Cannot send data, not connected.")
			return
		if !_packet_peer or !_stream_peer:
			printerr("NetworkConnectionServer: Cannot send data, peers invalid or stream closed.")
			_report_disconnection("Attempted to send data on closed stream.")
			return

		# Create the packet [type, ...data]
		var packet_data := data.duplicate() # Ensure we don't modify original array
		packet_data.push_front(type)
		
		# Send the packet
		var err: Error = _packet_peer.put_var(packet_data, false) # Set use_compression to true if desired
		if err != OK:
			printerr("NetworkConnectionServer: Failed to send packet '", type, "'. Error: ", err)
			_report_disconnection("Packet sending failed.")

	func _process(_delta: float) -> void:
		if not _stream_peer: return # Should not happen if initialized correctly

		_stream_peer.poll()
		var peer_status: StreamPeerTCP.Status = _stream_peer.get_status()

		match current_status:
			Status.CONNECTING:
				match peer_status:
					StreamPeerTCP.STATUS_CONNECTED:
						print("NetworkConnectionServer: Successfully connected to ", _address, ":", _port)
						current_status = Status.CONNECTED
						# Server should send init_request now.
					StreamPeerTCP.STATUS_CONNECTING:
						# Still connecting, check timeout? (Can use a Timer node)
						pass
					StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR:
						printerr("NetworkConnectionServer: Connection failed.")
						_report_disconnection("Connection failed during handshake.")
			Status.CONNECTED:
				match peer_status:
					StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_ERROR:
						# Connection dropped
						_report_disconnection("Connection lost (peer status error/none).")
					StreamPeerTCP.STATUS_CONNECTED:
						# Still connected, try receiving packets
						while _packet_peer and _packet_peer.get_available_packet_count() > 0:
							var received_var: Variant = _packet_peer.get_var(false) # Match compression setting of put_var
							if received_var == null and _packet_peer.get_packet_error() != OK:
								printerr("NetworkConnectionServer: Error receiving packet: ", _packet_peer.get_packet_error())
								_report_disconnection("Packet reception error.")
								break # Stop processing packets on error
								
							if received_var is Array and not received_var.is_empty():
								var packet_array: Array = received_var
								var packet_type: String = packet_array[0] as String
								if packet_type:
									packet_array.pop_front() # Remove the type from the data array
									packet_received.emit(packet_type, packet_array)
								else:
									printerr("NetworkConnectionServer: Received packet with invalid type (not String or null). Data: ", packet_array)
							elif received_var != null:
								printerr("NetworkConnectionServer: Received packet with unexpected format (not Array or null). Type: ", typeof(received_var))
			Status.DISCONNECTED, Status.ERROR:
				# Do nothing in process when already disconnected or in error state
				pass

# --- GameSession Main Logic ---

# Network connection instance (can be Integrated or Server type).
var network_connection: NetworkConnectionBase
# Current active world instance.
var world: World = null
# Current active battle instance.
var battle: Battle = null

# UI Nodes
@onready var disconnect_panel: Panel = $Overlay/DisconnectPanel
@onready var disconnect_label: Label = $Overlay/DisconnectPanel/Label
@onready var world_transition: ColorRect = $Overlay/WorldTransition
@onready var battle_layer: CanvasLayer = $BattleLayer

func _ready() -> void:
	# DEBUG: Initialize based on instance number (for multi-instance testing)
	if Global.instance_num == 0:
		# Instance 0 runs the integrated server
		print("GameSession: Running in integrated server mode (Instance 0).")
		var server_scene := preload("res://server/server.tscn")
		var server_instance: Server = server_scene.instantiate() as Server
		if server_instance:
			add_child(server_instance)
			network_connection = NetworkConnectionIntegrated.new(server_instance)
		else:
			printerr("GameSession: Failed to instantiate server scene!")
			network_connection = NetworkConnectionServer.new() # Fallback to normal connection
	else:
		# Other instances connect to the server
		print("GameSession: Running in client mode (Instance ", Global.instance_num, ").")
		network_connection = NetworkConnectionServer.new()

	# Add the network connection node and connect its signal
	if network_connection:
		add_child(network_connection)
		network_connection.packet_received.connect(_on_packet_received)
	else:
		printerr("GameSession: Network connection failed to initialize!")
		# Handle error: show message, disable network features?

	# Attempt to connect (for both integrated and server modes)
	if network_connection:
		network_connection.connect_to_server("127.0.0.1", 3115, Global.username)

# DEBUG INPUT - Remove or disable for production
func _input(event: InputEvent) -> void:
	if !network_connection: return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Q:
				network_connection.send_data("request_change_world")
			KEY_SPACE:
				network_connection.send_data("request_start_battle")


# Creates and adds a new World instance to the scene.
# Called by the 'world_init' packet handler.
func create_world(world_state: Dictionary) -> void:
	if world:
		printerr("GameSession.create_world: Attempted to create world when one already exists. Ignoring.")
		return

	var new_world: World = WORLD_SCENE.instantiate() as World
	if !new_world:
		printerr("GameSession.create_world: Failed to instantiate WORLD_SCENE.")
		return

	# Crucial: Provide the network connection to the new world BEFORE adding it
	# so its managers can be initialized correctly in _ready.
	new_world.network_connection = network_connection
	
	# Add to the main scene tree
	add_child(new_world)
	world = new_world
	
	# Apply initial state
	world.deserialize(world_state)
	print("GameSession: World created and initialized.")


# Central packet handling logic. Routes packets to the appropriate handler.
func _on_packet_received(type: String, data: Array) -> void:
	# print("Received packet: Type=", type, ", Data=", data) # Debug logging
	var handler: PacketHandlerClient = PacketHandlerClient.get_handler(type)
	if handler:
		# Execute the handler's run method
		handler.run(self, data)
	else:
		# Error message already printed by get_handler
		pass

# Clean up when the GameSession node is removed
func _exit_tree() -> void:
	print("GameSession exiting tree.")
	if network_connection:
		network_connection.leave_server()
		# Consider removing child node network_connection here if not done automatically
