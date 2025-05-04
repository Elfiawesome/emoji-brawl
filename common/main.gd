class_name MainEntryPoint extends Node

const CLIENT_SCENE := preload("res://client/client.tscn")
const SERVER_SCENE := preload("res://server/server.tscn")

var server: Server
var client: Client

func _ready() -> void:
	client = CLIENT_SCENE.instantiate()
	add_child(client)
	
	if Global.instance_num == 0:
		server = SERVER_SCENE.instantiate()
		add_child(server)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if server:
			server.shutdown()
