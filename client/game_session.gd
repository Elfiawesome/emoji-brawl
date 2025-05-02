class_name GameSession extends Node

var network_connection: NetworkConnectionBase
var avatars: Dictionary[String, Avatar] = {}
var local_avatar_id: String

@onready var disconnect_panel: Panel = $CanvasLayer/Panel
@onready var disconnect_label: Label = $CanvasLayer/Panel/Label

func _ready() -> void:
	if Global.instance_num == 0:
		var server := preload("res://server/server.tscn").instantiate()
		add_child(server)
		network_connection = NetworkConnectionIntegrated.new(server)
		#network_connection = NetworkConnectionServer.new()
	else:
		network_connection = NetworkConnectionServer.new()
	
	network_connection.packet_received.connect(_on_handle_data)
	add_child(network_connection)
	network_connection.connect_to_server("127.0.0.1", 3115, Global.username)

func get_input() -> Vector2:
	var speed := 300
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return input_direction * speed

func _process(delta: float) -> void:
	if local_avatar_id in avatars:
		var move := get_input()
		if move != Vector2.ZERO:
			avatars[local_avatar_id].position += (move * delta)
			network_connection.send_data("update_avatar_position", [avatars[local_avatar_id].position])

func _on_handle_data(type: String, data: Array) -> void:
	#print("Client["+str(Global.instance_num)+"] packet: " + type + " -> " +str(data))
	var handler := PacketHandlerClient.get_handler(type)
	if !handler: return
	handler.run(self, data)

class NetworkConnectionBase extends Node:
	var username: String
	
	signal packet_received(type: String, data: Array)
	func _init() -> void: name = "NetworkConnection"
	func connect_to_server(_address: String, _port: int, _username: String) -> void: pass
	func get_status() -> int: return 0
	func leave_server() -> void: pass
	func send_data(_type: String, _data: Array = []) -> void: pass

class NetworkConnectionIntegrated extends NetworkConnectionBase:
	var server: Server
	var client: Server.ClientIntegrated
	
	func _init(server_: Server) -> void:
		super._init()
		server = server_
	
	func connect_to_server(_address: String, _port: int, username_: String) -> void:
		client = server.ClientIntegrated.new()
		server.take_client_connection(client)
		client.packet_sent.connect(_on_packet_received)
		username = username_
		client.packet_received.emit("connection_request", [username])
	
	func send_data(type: String, data: Array = []) -> void:
		client.packet_received.emit(type, data)
	
	func _on_packet_received(type: String, data: Array) -> void:
		packet_received.emit(type, data)

class NetworkConnectionServer extends NetworkConnectionBase:
	var address: String
	var port: int
	
	var stream_peer: StreamPeerTCP
	var packet_peer: PacketPeerStream
	
	func _init() -> void:
		super._init()
	
	func connect_to_server(address_: String, port_: int, username_: String) -> void:
		address = address_
		port = port_
		
		stream_peer = StreamPeerTCP.new()
		packet_peer = PacketPeerStream.new()
		
		stream_peer.connect_to_host(address, port)
		packet_peer.stream_peer = stream_peer
		
		username = username_
	func get_status() -> int:
		if stream_peer: return stream_peer.get_status()
		return stream_peer.Status.STATUS_NONE
	
	func disconnect_from_server(disconnect_reason: String = "Unknown disconnected by server.") -> void:
		var disconnect_data := {"reason": disconnect_reason}
		packet_received.emit("force_disconnect", [disconnect_data])
		leave_server()
	
	func leave_server() -> void:
		stream_peer.disconnect_from_host()
		queue_free()
	
	func send_data(type: String, data: Array = []) -> void:
		stream_peer.poll()
		var new_data := data.duplicate()
		new_data.push_front(type)
		packet_peer.put_var(new_data)
	
	func _process(_delta: float) -> void:
		if !stream_peer: return
		stream_peer.poll()
		
		var status := stream_peer.get_status()
		if (status == stream_peer.Status.STATUS_ERROR) or (status == stream_peer.Status.STATUS_NONE):
			disconnect_from_server()
		
		while (packet_peer.get_available_packet_count() > 0):
			var data: Variant = packet_peer.get_var()
			if data is Array:
				if data.size() < 1: return
				var packet_type: String = data[0]
				data.pop_at(0)
				var packet_data: Array = data
				packet_received.emit(packet_type, packet_data)
