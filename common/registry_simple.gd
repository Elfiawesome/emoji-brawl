class_name RegistrySimple extends RefCounted
## A simple registry class to map string keys to Objects or Resources.

# Internal dictionary storing the registered items. [String -> Variant]
var _map: Dictionary = {}

# Enum to define how objects are loaded/instantiated when registering from a folder.
enum InstantiationType {
	REGISTER_RESOURCE,      # Register the loaded Resource itself (e.g., PackedScene, GDScript).
	INSTANCE_AS_CLASS       # If the Resource is a GDScript, instantiate it using .new().
}

# Retrieves an object/resource from the registry by its name (key).
# Returns null if the name is not found.
func get_object(name: String) -> Variant:
	if not _map.has(name):
		printerr("RegistrySimple: Object with name '", name, "' not found.")
		return null
	return _map.get(name)


# Scans a folder and registers objects based on the files found.
# Assumes the filename (without extension) is the desired registration key.
func register_all_objects_in_folder(folder_path: String, instance_load_type: InstantiationType = InstantiationType.REGISTER_RESOURCE) -> void:
	if not DirAccess.dir_exists_absolute(folder_path):
		printerr("RegistrySimple: Folder not found: ", folder_path)
		return

	var dir := DirAccess.open(folder_path)
	if not dir:
		printerr("RegistrySimple: Could not open directory: ", folder_path)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "gd": # Process only .gd script files
			var id: String = file_name.get_basename() # Use filename without extension as ID
			var full_path: String = folder_path.path_join(file_name)
			
			# Important: Use ResourceLoader.load to get the script resource
			var script_resource: GDScript = load(full_path) as GDScript

			if not script_resource:
				printerr("RegistrySimple: Failed to load script resource: ", full_path)
			else:
				match instance_load_type:
					InstantiationType.REGISTER_RESOURCE:
						register_object(id, script_resource)
						# print("Registered resource: ", id)
					InstantiationType.INSTANCE_AS_CLASS:
						# Check if it's a valid script that can be instantiated
						if script_resource is GDScript:
							var instance: Object = script_resource.new()
							if instance:
								register_object(id, instance)
								# print("Registered instance: ", id)
							else:
								printerr("RegistrySimple: Failed to instantiate script: ", full_path)
						else:
							printerr("RegistrySimple: Resource is not a GDScript, cannot instantiate: ", full_path)
							
		file_name = dir.get_next()

	dir.list_dir_end() # Not strictly needed as DirAccess closes automatically when var goes out of scope


# Scans a folder and registers all PackedScene resources found.
# Assumes the filename (without extension) is the desired registration key.
func register_all_scenes_in_folder(folder_path: String) -> void:
	if not DirAccess.dir_exists_absolute(folder_path):
		printerr("RegistrySimple: Folder not found: ", folder_path)
		return

	var dir := DirAccess.open(folder_path)
	if not dir:
		printerr("RegistrySimple: Could not open directory: ", folder_path)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		# Process only .tscn scene files
		if not dir.current_is_dir() and file_name.get_extension() == "tscn":
			var id: String = file_name.get_basename()
			var full_path: String = folder_path.path_join(file_name)
			var scene_resource: PackedScene = ResourceLoader.load(full_path)

			if scene_resource is PackedScene:
				register_object(id, scene_resource)
				# print("Registered scene: ", id)
			else:
				printerr("RegistrySimple: Failed to load resource as PackedScene: ", full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


# Registers a single object/resource with a given name (key).
# Overwrites existing entry if the name already exists.
func register_object(name: String, object_to_register: Variant) -> void:
	if name == "":
		printerr("RegistrySimple: Attempted to register object with empty name.")
		return
	if object_to_register == null:
		printerr("RegistrySimple: Attempted to register null object for name '", name, "'.")
		return
		
	if _map.has(name):
		push_warning("RegistrySimple: Overwriting existing registration for name '", name, "'.")
		
	_map[name] = object_to_register


# Returns an array containing all registered keys (names).
func get_registries() -> Array:
	return _map.keys()


# Checks if a specific name (key) is present in the registry.
func contains(name: String) -> bool:
	return _map.has(name)
