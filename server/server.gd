class_name Server extends Node
## Main server node. Manages the TCP listener, client connections,
## and high-level server managers (World Manager, Network Bus).

# --- Network Communication ---
# Handles sending data to specific clients or broadcasting.
class NetworkBus extends RefCounted:
	var server: Server # Reference back to the main Server node.

	func _init(server_instance: Server) -> void:
		if !server_instance:
			printerr("NetworkBus: Invalid Server instance provided during initialization!")
			# Cannot function without server reference.
		server = server_instance

	# Sends data to a single client identified by their ID.
	func send_data(client_id: String, type: String, data: Array = []) -> void:
		if not server: return # Cannot operate
		if server.clients.has(client_id):
			var client: ClientBase = server.clients[client_id]
			if client:
				client.send_data(type, data)
			else:
				printerr("NetworkBus.send_data: Client instance for ID '", client_id, "' is invalid.")
				# Maybe cleanup server.clients entry? Risky if called during iteration.
		else:
			# Don't print error for sends to non-existent clients, might be common
			# if client disconnects while message is in flight.
			# print("NetworkBus.send_data: Client ID '", client_id, "' not found.")
			pass

	# Sends data to all currently connected clients.
	func broadcast_data(type: String, data: Array = []) -> void:
		if not server: return
		# print("Broadcasting: ", type, data) # Debug
		# Iterate safely in case clients disconnect during broadcast
		for client_id: String in server.clients.keys():
			send_data(client_id, type, data)

	# Sends data to a specific list of clients.
	func broadcast_specific_data(client_ids: Array, type: String, data: Array = []) -> void:
		if not server: return
		# print("Broadcasting to specific: ", client_ids, type, data) # Debug
		for client_id: String in client_ids:
			# Check if the ID from the list is actually a String
			if client_id is String:
				send_data(client_id, type, data)
			else:
				printerr("NetworkBus.broadcast_specific_data: Invalid client ID type in list: ", typeof(client_id))


# --- Base Client Representation ---
# Abstract base class for different connection types (TCP, Integrated).
class ClientBase extends Node:
	signal packet_received(type: String, data: Array) # Emitted when this client receives data.

	# Client Identification & State
	var id: String = ""             # Unique ID assigned on connection (usually username/hash).
	var username: String = "Unknown"
	var color: Color = Color.WHITE
	var state: State = State.NONE # Current state in the connection lifecycle.

	# Client Game Context (Routing Info)
	var current_world_id: String = ""       # ID of the world the client is currently in.
	var controlled_avatar_id: String = "" # ID of the avatar this client controls.
	var current_battle_id: String = ""    # ID of the battle the client is currently in.

	enum State {
		NONE,      # Initial state before connection established/request received.
		REQUEST,   # Connection established, waiting for/processing connection_request.
		PLAY       # Client is fully connected and interacting with the game world.
	}

	# Timer to disconnect clients that don't send a connection_request quickly enough.
	var _handshake_timer: Timer

	func _init() -> void:
		pass

	func _ready() -> void:
		# Start a timer to ensure the client sends connection_request promptly.
		_handshake_timer = Timer.new()
		_handshake_timer.one_shot = true
		_handshake_timer.wait_time = 10.0 # Allow 10 seconds for handshake
		_handshake_timer.timeout.connect(_on_handshake_timeout)
		add_child(_handshake_timer)
		_handshake_timer.start()

	func _on_handshake_timeout() -> void:
		if state != State.PLAY:
			printerr("Client '", id if id != "" else "[No ID]", "' timed out waiting for connection_request.")
			force_disconnect("Handshake timeout: No connection request received.")
		# Timer is one-shot, no need to stop manually unless reusing.
		# Can queue_free timer here if desired: _handshake_timer.queue_free()

	# Forces the disconnection of this client, sending a reason.
	# Cleans up server state via 'connection_lost' packet handling.
	func force_disconnect(reason: String = "Disconnected by server.") -> void:
		print("Force disconnecting client '", id if id != "" else "[No ID]", "'. Reason: ", reason)
		if state == State.NONE and id == "": # Already disconnected or never connected fully
			if is_inside_tree(): queue_free() # Just remove the node if it never registered
			return

		# 1. Send the disconnect message (if possible)
		var disconnect_data := {"reason": reason}
		send_data("force_disconnect", [disconnect_data])

		# 2. Trigger internal cleanup handler ('connection_lost')
		packet_received.emit("connection_lost", [])

		# 3. Stop the handshake timer if it's still running
		if _handshake_timer and not _handshake_timer.is_stopped():
			_handshake_timer.stop()

		# 4. Free the client node itself after a short delay to allow signals/cleanup.
		# Using call_deferred ensures it happens in the next idle frame.
		call_deferred("queue_free")
		# Mark state as NONE to prevent further actions?
		state = State.NONE
		id = "" # Clear ID to prevent re-finding in lists


	# Abstract method for sending data back to the client.
	func send_data(_type: String, _data: Array = []) -> void:
		# Implemented by subclasses (ClientConnection, ClientIntegrated)
		printerr("ClientBase.send_data() called directly!")
		pass

	# Called when the node is about to be removed from the tree.
	func _exit_tree() -> void:
		print("ClientBase node '", name, "' (ID: ", id if id != "" else "[No ID]", ") exiting tree.")
		# Ensure timer is cleaned up if node is freed externally
		if _handshake_timer:
			_handshake_timer.queue_free()

# --- Integrated Client (For In-Process Server/Client) ---
class ClientIntegrated extends ClientBase:
	# Signal used by the *client-side* NetworkConnectionIntegrated to receive data.
	signal packet_sent(type: String, data: Array)

	func _init() -> void:
		super._init()
		name = "ClientIntegrated_" + str(get_instance_id()) # Unique name

	func send_data(type: String, data: Array = []) -> void:
		# Emit signal for the client-side counterpart to receive.
		packet_sent.emit(type, data)

	# Callback used by the *client-side* NetworkConnectionIntegrated to send data *to* the server.
	func _on_packet_received_from_client(type: String, data: Array) -> void:
		# Emit the standard packet_received signal for server-side handlers.
		packet_received.emit(type, data)


# --- TCP Client Connection ---
class ClientConnection extends ClientBase:
	var _stream_peer: StreamPeerTCP
	var _packet_peer: PacketPeerStream

	# Takes ownership of the StreamPeerTCP connection.
	func _init(connection: StreamPeerTCP) -> void:
		super._init()
		if not connection or not connection is StreamPeerTCP:
			printerr("ClientConnection: Invalid StreamPeerTCP provided.")
			# Cannot proceed without connection, free self?
			queue_free()
			return
			
		_stream_peer = connection
		_stream_peer.set_no_delay(true) # Improve responsiveness for game packets
		_packet_peer = PacketPeerStream.new()
		_packet_peer.stream_peer = _stream_peer
		name = "ClientConnection_" + str(_stream_peer.get_connected_host()) + "_" + str(_stream_peer.get_connected_port())
		print("Client connection established from: ", name)
		
		# Initiate handshake: Tell the client to send its connection request.
		send_data("init_request")

	func force_disconnect(reason: String = "Disconnected by server.") -> void:
		# Perform base class actions (send message, trigger cleanup, free node)
		super.force_disconnect(reason)
		# Also explicitly close the TCP connection if it's still open
		if _stream_peer:
			_stream_peer.disconnect_from_host()
		_stream_peer = null # Clear references
		_packet_peer = null

	func _process(_delta: float) -> void:
		if not _stream_peer:
			# Connection was likely closed or never established properly.
			# Ensure node is freed if it hasn't been already.
			if is_inside_tree(): force_disconnect("Stream peer invalid in _process.")
			return

		_stream_peer.poll() # Update connection status
		var peer_status: StreamPeerTCP.Status = _stream_peer.get_status()

		# Check for disconnection
		if peer_status == StreamPeerTCP.STATUS_NONE or peer_status == StreamPeerTCP.STATUS_ERROR:
			# Connection lost unexpectedly.
			if state != State.NONE: # Avoid redundant disconnect if already handled
				force_disconnect("Connection lost (peer status error/none).")
			return # Stop processing if disconnected

		# Receive incoming packets if connected
		if peer_status == StreamPeerTCP.STATUS_CONNECTED and _packet_peer:
			while _packet_peer.get_available_packet_count() > 0:
				var received_var: Variant = _packet_peer.get_var(false) # Match compression
				
				if received_var == null and _packet_peer.get_packet_error() != OK:
					printerr("Client '", id, "': Error receiving packet: ", error_string(_packet_peer.get_packet_error()))
					force_disconnect("Packet reception error.")
					break # Stop processing packets for this frame on error
					
				if received_var is Array and not received_var.is_empty():
					var packet_array: Array = received_var
					# Validate type is String before processing
					var packet_type: String = packet_array[0] as String
					if packet_type:
						packet_array.pop_front() # Remove type from data array
						packet_received.emit(packet_type, packet_array)
					else:
						printerr("Client '", id, "': Received packet with invalid type (not String or null). Data: ", packet_array)
						# Consider disconnecting client sending malformed data?
				elif received_var != null: # Received something, but not a valid array packet
					printerr("Client '", id, "': Received packet with unexpected format (not Array or null). Type: ", typeof(received_var))
					# Consider disconnecting client sending malformed data?

	# Sends data back to the connected client via TCP.
	func send_data(type: String, data: Array = []) -> void:
		if not _stream_peer:
			# printerr("Client '", id, "': Cannot send data, not connected.") # Reduce log spam
			return
		if not _packet_peer:
			printerr("Client '", id, "': Cannot send data, PacketPeerStream is invalid.")
			return

		# Construct packet: [type, ...data]
		var packet_data := data.duplicate()
		packet_data.push_front(type)

		# Send the packet
		var err: Error = _packet_peer.put_var(packet_data, false) # Match compression
		if err != OK:
			printerr("Client '", id, "': Failed to send packet '", type, "'. Error: ", error_string(err))

# --- Server Main Logic ---

# Server Configuration
const DEFAULT_PORT: int = 3115
const DEFAULT_ADDRESS: String = "0.0.0.0" # Listen on all available interfaces

# Core Components
var network_bus: NetworkBus
var world_manager: WorldServerManager

# Networking State
var _tcp_server: TCPServer
# Dictionary storing active client connections/handlers, keyed by client ID.
var clients: Dictionary[String, ClientBase] = {}

func _ready() -> void:
	print("Server: Initializing...")
	_initialize_managers()
	_initialize_network()
	_load_initial_worlds()
	print("Server: Ready and listening on ", _tcp_server.get_local_port())


# Initialize high-level managers.
func _initialize_managers() -> void:
	network_bus = NetworkBus.new(self)
	if not network_bus: printerr("Server: Failed to initialize NetworkBus!")
		
	world_manager = WorldServerManager.new(network_bus)
	if world_manager:
		add_child(world_manager) # Add manager to the scene tree
	else:
		printerr("Server: Failed to initialize WorldServerManager!")


# Set up the TCP listener.
func _initialize_network() -> void:
	_tcp_server = TCPServer.new()
	var listen_port := DEFAULT_PORT
	var listen_address := DEFAULT_ADDRESS
	
	var err := _tcp_server.listen(listen_port, listen_address)
	if err != OK:
		printerr("Server: Failed to start TCP listener on ", listen_address, ":", listen_port, ". Error: ", error_string(err))
		# Handle critical error - maybe quit?
		get_tree().quit()
	else:
		print("Server: TCP Listener started on ", listen_address, ":", listen_port)


# Load initial game worlds.
func _load_initial_worlds() -> void:
	if world_manager:
		# Example worlds - load based on configuration or level data
		world_manager.load_world("meadow")
		world_manager.load_world("cave")
	else:
		printerr("Server: Cannot load initial worlds, World Manager is invalid.")


# Called every frame. Checks for new incoming TCP connections.
func _process(_delta: float) -> void:
	# Accept new TCP connections if available
	if _tcp_server and _tcp_server.is_connection_available():
		var connection: StreamPeerTCP = _tcp_server.take_connection()
		if connection:
			print("Server: New TCP connection received from ", connection.get_connected_host(), ":", connection.get_connected_port())
			var client_handler := ClientConnection.new(connection)
			# take_client_connection will add as child and connect signals
			take_client_connection(client_handler)
		else:
			printerr("Server: Failed to take incoming TCP connection.")


# Registers a new client handler (either TCP or Integrated).
# Connects signals and adds the handler node as a child.
func take_client_connection(client_handler: ClientBase) -> void:
	if not client_handler:
		printerr("Server: Attempted to take an invalid client handler instance.")
		return

	# Connect the handler's packet_received signal to the server's dispatcher.
	client_handler.packet_received.connect(_on_client_packet_received.bind(client_handler))
	
			
	# Add the client handler node to the server's scene tree.
	# This ensures it participates in the _process loop (for ClientConnection) and is managed properly.
	add_child(client_handler)
	print("Server: Client handler '", client_handler.name, "' registered.")


# Central dispatcher for packets received from any client handler.
# Routes the packet to the appropriate PacketHandlerServer.
func _on_client_packet_received(type: String, data: Array, client: ClientBase) -> void:
	# print("Server received from '", client.id, "': Type=", type, ", Data=", data) # Debug
	if not client:
		printerr("Server: Received packet from an invalid client instance. Type: ", type)
		return

	var handler: PacketHandlerServer = PacketHandlerServer.get_handler(type)
	if handler:
		# Execute the handler logic
		handler.run(self, client, data)
	else:
		# Error already printed by get_handler.
		# Consider disconnecting client sending unknown packet types?
		# client.force_disconnect("Sent unknown packet type: " + type)
		pass # For now, just ignore unknown types


# Called when the server node is removed from the scene tree.
func _exit_tree() -> void:
	print("Server: Shutting down...")
	# Gracefully disconnect all clients
	# Iterate over a copy of keys as force_disconnect modifies the dictionary
	for client_id: String in clients.keys():
		if clients.has(client_id):
			var client: ClientBase = clients[client_id]
			if client:
				client.force_disconnect("Server is shutting down.")
			else:
				# Clean up entry if instance became invalid somehow
				clients.erase(client_id)

	# Stop the TCP server listener
	if _tcp_server:
		_tcp_server = null # Stop listening and release port

	print("Server: Shutdown complete.")
