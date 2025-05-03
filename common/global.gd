extends Node

# Instance number, typically set via command line args for multi-instance testing.
var instance_num: int = 0
# Username for the current game instance.
var username: String = "Player"
# Process ID of the current instance (less common use).
var pid: int = 0

const WINDOW_BASE_POS := Vector2i(0, 40) # Offset from screen top-left to avoid overlap with taskbars etc.

func _ready() -> void:
	_configure_instance()
	pid = OS.get_process_id()
	print("Global: Instance ", instance_num, " initialized. User: '", username, "', PID: ", pid)

# Configures window position and title based on instance number for easier multi-instance testing.
# Only runs in debug builds where command line args are expected.
func _configure_instance() -> void:
	if not OS.is_debug_build():
		# In release builds, maybe generate a unique username or load from save
		username = _generate_unique_username()
		return

	var args: PackedStringArray = OS.get_cmdline_args()
	# Expecting the instance number as the *second* argument (index 1), after the executable path.
	if args.size() > 1 and args[1].is_valid_int():
		instance_num = args[1].to_int()
		username = "Player " + str(instance_num)
	else:
		# Default to instance 0 if no valid arg is provided
		instance_num = 0
		username = "Player " + str(instance_num)
		print("Global: No valid instance number argument found, defaulting to 0.")

	# --- Window Positioning ---
	var main_window: Window = get_window()
	if not main_window:
		printerr("Global: Could not get main window reference.")
		return

	main_window.title = "Instance " + str(instance_num) + " - Emoji Brawl"

	# Get usable screen rect (excluding taskbars etc.)
	var screen_index: int = DisplayServer.window_get_current_screen(main_window.get_window_id())
	var screen_rect: Rect2 = DisplayServer.screen_get_usable_rect(screen_index)
	var screen_size := Vector2(screen_rect.size)
	
	# Use integer division for positioning to potentially avoid subpixel issues
	var window_size := Vector2i(main_window.size) # Use configured size
	# Ensure window isn't larger than half the screen for this layout
	window_size = window_size.min(Vector2i(screen_size / 2.0)) 
	main_window.size = window_size # Apply potentially clamped size

	var target_pos := Vector2(WINDOW_BASE_POS) + screen_rect.position # Start relative to usable area origin

	# Position windows in a 2x2 grid within the usable screen area
	match instance_num % 4: # Use modulo 4 for more instances
		0: # Top-left
			target_pos += Vector2(0, 0)
		1: # Top-right
			target_pos += Vector2(screen_size.x / 2, 0)
		2: # Bottom-left
			target_pos += Vector2(0, screen_size.y / 2)
		3: # Bottom-right
			target_pos += Vector2(screen_size.x / 2, screen_size.y / 2)

	main_window.position = target_pos


# Generates a unique-ish username (placeholder implementation).
func _generate_unique_username() -> String:
	# Simple approach: "Player" + random number.
	# Better approaches might involve user input, saved profiles, or platform IDs.
	randomize() # Ensure random seed
	return "Player" + str(randi_range(1000, 9999))