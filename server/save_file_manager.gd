class_name SaveManager extends Node

const SERVER_CONFIG_FILE = "server-config.json"

class GameConfig:
	var port: int
	var address: String
	
	func _init() -> void: default()
	
	func default() -> void:
		port = 3115
		address = "127.0.0.1"
	
	func to_dict() -> Dictionary: return { "port": port, "address": address}
	
	func from_dict(config_dict: Dictionary) -> void:
		port = config_dict.get("port", port)
		address = config_dict.get("address", address)


enum SaveSections { ROOT, MAP, BATTLE, PLAYER }
const SAVE_SECTIONS: Dictionary[SaveSections, String] = {
	SaveSections.ROOT: "",
	SaveSections.MAP: "map",
	SaveSections.BATTLE: "battle",
	SaveSections.PLAYER: "player"
}

var dir: DirAccess
var config: GameConfig

@warning_ignore("unused_parameter")
func load_save(save_name: String) -> void:
	if dir == null: return
	# Create/Load config file
	load_server_config_file()

func new_save(save_name: String) -> void:
	var save_dir := "user://saves/" + save_name
	if DirAccess.dir_exists_absolute(save_dir):
		pass
	else:
		DirAccess.make_dir_recursive_absolute(save_dir)
	dir = DirAccess.open(save_dir)
	load_save(save_name)

func load_server_config_file() -> void:
	if dir == null: return
	var server_config_file := _get_abs_item_path(SaveSections.ROOT, SERVER_CONFIG_FILE)
	config = GameConfig.new()
	config.from_dict(_load_abs_json_file(server_config_file, config.to_dict()))

# Get the map.json file data
func load_map_state(map_name: String) -> Dictionary:
	var map_json := _get_abs_item_path(SaveSections.MAP, map_name, ".json")
	var default_map_data := {"map_id": map_name, "description": ""}
	# Get our game's default map data
	var default_map_file := "res://asset/default_maps/"+map_name+".json"
	if FileAccess.file_exists(default_map_file):
		var _f := FileAccess.open(default_map_file, FileAccess.READ)
		default_map_data = JSON.parse_string(_f.get_as_text())
		_f.close()
	return _load_abs_json_file(map_json, default_map_data)

# Stores the map.json file data
func save_map_state(map_name: String, map_data: Dictionary) -> void:
	var map_json := _get_abs_item_path(SaveSections.MAP, map_name, ".json")
	var f := FileAccess.open(map_json, FileAccess.WRITE)
	f.store_string(JSON.stringify(map_data))
	f.close()

func _get_abs_item_path(save_section: SaveSections, file_name: String, extension: String = "") -> String:
	var path := SAVE_SECTIONS[save_section]
	if path:
		if !dir.dir_exists(path + "/" + file_name.get_base_dir()):
			dir.make_dir_recursive(path + "/" + file_name.get_base_dir())
	return dir.get_current_dir() + "/" + path + "/" + file_name + extension

func _load_abs_json_file(asb_file_path: String, default_value: Dictionary = {}) -> Dictionary:
	if dir.file_exists(asb_file_path):
		var f := FileAccess.open(asb_file_path, FileAccess.READ)
		if f != null:
			return JSON.parse_string(f.get_as_text())
	else:
		var f := FileAccess.open(asb_file_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(default_value))
			f.close()
	return default_value

func _dumps_abs_json_file(abs_file_path: String, data: Dictionary) -> void:
	var f := FileAccess.open(abs_file_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
