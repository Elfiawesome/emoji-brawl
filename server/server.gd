class_name Server extends Node

var network_bus: NetworkBus

var tcp_server: TCPServer
var clients: Dictionary[String, ClientBase] = {}
var is_battle: bool = false

func _ready() -> void:
	initialize_managers()
	initialize_server()

func initialize_managers() -> void:
	network_bus = NetworkBus.new(self)

func initialize_server() -> void:
	var port := 3115
	var address := "127.0.0.1"
	tcp_server = TCPServer.new()
	tcp_server.listen(port, address)

func _process(_delta: float) -> void:
	if tcp_server.is_connection_available():
		var client := ClientConnection.new(tcp_server.take_connection())
		take_client_connection(client)
	
	var avatars_data := {}
	for client_id in clients:
		var client := clients[client_id]
		if client.is_avatar_changed:
			avatars_data[client.avatar_id] = client.avatar_position
			client.is_avatar_changed = false
	if !avatars_data.is_empty():
		for client_id in clients:
			var client := clients[client_id]
			var _avatar_data := avatars_data.duplicate()
			_avatar_data.erase(client.avatar_id)
			network_bus.send_data(client_id, "update_avatars_position", [_avatar_data])

func take_client_connection(client: ClientBase) -> void:
	client.packet_received.connect(_on_client_handle_data.bind(client))
	add_child(client)

func _on_client_handle_data(type: String, data: Array, client: ClientBase) -> void:
	#print("Server packet: " + type + " -> " +str(data) + " {" + str(client.id) + "}")
	var handler := PacketHandlerServer.get_handler(type)
	if !handler: return
	handler.run(self, client, data)

class NetworkBus extends RefCounted:
	var server: Server
	func _init(server_: Server) -> void:
		server = server_
	func send_data(client_id: String, type: String, data: Array = []) -> void:
		if !server.clients.has(client_id): return
		var client := server.clients[client_id]
		client.send_data(type, data)
	func broadcast_data(type: String, data: Array = []) -> void:
		for client_id in server.clients:
			var client := server.clients[client_id]
			client.send_data(type, data)
	func broadcast_specific_data(clients_list: Array, type: String, data: Array = []) -> void:
		for client_id: String in clients_list:
			if server.clients.has(client_id):
				var client := server.clients[client_id]
				client.send_data(type, data)

class ClientBase extends Node:
	signal packet_received(type: String, data: Array)
	
	var avatar_id: String
	var avatar_position: Vector2
	var is_avatar_changed: bool = false
	var state: State = State.NONE
	var id: String
	
	enum State {
		NONE = 0,
		REQUEST,
		PLAY
	}
	
	func _ready() -> void:
		var t := Timer.new()
		add_child(t)
		t.start(1)
		t.one_shot = true
		t.timeout.connect(
			func() -> void:
				t.queue_free()
				if state != State.PLAY:
					force_disconnect("Timeout. No connection request was made by client.")
		)
	
	func force_disconnect(disconnect_reason: String = "Unknown disconnected by server.") -> void:
		var disconnect_data := {"reason": disconnect_reason}
		send_data("force_disconnect", [disconnect_data])
		packet_received.emit("connection_lost", [disconnect_data])
		queue_free()
	
	func send_data(_type: String, _data: Array = []) -> void: pass

class ClientIntegrated extends ClientBase:
	signal packet_sent(type: String, data: Array)
	
	func send_data(type: String, data: Array = []) -> void:
		packet_sent.emit(type, data)

class ClientConnection extends ClientBase:
	var stream_peer: StreamPeerTCP
	var packet_peer: PacketPeerStream
	
	func _init(connection: StreamPeerTCP) -> void:
		stream_peer = connection
		packet_peer = PacketPeerStream.new()
		packet_peer.stream_peer = stream_peer
		send_data("init_request")
	
	func force_disconnect(disconnect_reason: String = "Unknown disconnected by server.") -> void:
		super.force_disconnect(disconnect_reason)
		stream_peer.disconnect_from_host()
	
	func _process(_delta: float) -> void:
		stream_peer.poll()
		
		var status := stream_peer.get_status()
		if (status == stream_peer.Status.STATUS_ERROR) or (status == stream_peer.Status.STATUS_NONE):
			force_disconnect("Unkown disconnected by player.")
		
		while (packet_peer.get_available_packet_count() > 0):
			var data: Variant = packet_peer.get_var()
			if data is Array:
				if data.size() < 1: return
				var packet_type: String = data[0]
				data.pop_at(0)
				var packet_data: Array = data
				packet_received.emit(packet_type, packet_data)
	
	func send_data(type: String, data: Array = []) -> void:
		var new_data := data.duplicate()
		new_data.push_front(type)
		stream_peer.poll()
		packet_peer.put_var(new_data)
