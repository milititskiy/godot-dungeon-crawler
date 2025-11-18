extends CharacterBody2D

var grid_x: int = 0
var grid_y: int = 0
var game_field: Node2D
var tile_size: int = 64
var tile_spacing: int = 2
var move_speed: float = 300.0

# Pathfinding variables
var current_path: Array[Vector2i] = []
var path_index: int = 0
var is_moving: bool = false
var move_tween: Tween

signal moved(new_x: int, new_y: int)
signal path_completed()

func _ready():
	# Find the game field reference
	game_field = get_parent()
	# Connect to tile clicks for pathfinding
	connect_to_tiles()

func _physics_process(_delta):
	handle_input()

func _input(event):
	# Handle right click for combat menu or stop movement
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Check if right-clicking on an adjacent enemy for combat
		if try_open_combat_menu(event.position):
			return  # Combat menu opened, don't stop movement
		else:
			stop_movement()  # Normal right-click behavior
		return
		
	# Global input handling for tile clicks
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("=== PLAYER LEFT CLICK ===")
		print("Click position: ", event.position)
		print("Game field exists: ", game_field != null)
		
		# Check if clicking on combat menu - don't close it if so
		if game_field.active_combat_menu:
			var menu_rect = Rect2(game_field.active_combat_menu.position, Vector2(120, 80))
			print("Combat menu rect: ", menu_rect)
			if menu_rect.has_point(event.position):
				print("Click on combat menu - not closing")
				return  # Don't close menu or process movement
			else:
				print("Click outside combat menu - closing")
				game_field.hide_combat_menu()
				return  # Don't process movement when closing menu
			
		handle_mouse_click(event.position)

func handle_mouse_click(_screen_pos: Vector2):
	# Check if we're in battle mode - restrict movement during battle
	if game_field.is_in_battle:
		print("Cannot move - in battle mode")
		return
	
	# Convert screen position to world position
	var camera = game_field.get_node("Camera2D")
	var world_pos = camera.get_global_mouse_position()
	print("World position: ", world_pos)
	
	# Check if this click is likely on a UI element by checking if it's in the UI areas
	# UI panels are typically at screen edges, so check if world position is near camera edges
	var camera_pos = camera.global_position
	var zoom = camera.zoom
	var screen_size = get_viewport().get_visible_rect().size
	var world_screen_size = screen_size / zoom
	
	# If click is in the UI areas (left edge where panels are), ignore it
	if world_pos.x < camera_pos.x - world_screen_size.x/2 + 200: # Left 200 pixels are UI
		print("Click appears to be on UI, ignoring")
		return
	
	# Convert world position to grid coordinates
	var grid_pos = world_to_grid_position(world_pos)
	print("Grid position: ", grid_pos)
	
	# Highlight the clicked tile
	game_field.highlight_tile(grid_pos)
	
	# Check if the grid position is valid
	if grid_pos.x >= 0 and grid_pos.x < game_field.grid_size and grid_pos.y >= 0 and grid_pos.y < game_field.grid_size:
		# Check if we can move there
		if not is_moving and game_field.is_walkable_for_character(grid_pos.x, grid_pos.y, self):
			print("Moving to grid position: (", grid_pos.x, ", ", grid_pos.y, ")")
			move_to_position(Vector2i(grid_pos.x, grid_pos.y))
		else:
			if is_moving:
				print("Cannot move - already moving")
			else:
				print("Cannot move - tile not walkable (obstacle or occupied)")
				# Note: Highlight was already prevented in highlight_tile() for non-walkable tiles
	else:
		print("Click outside grid bounds")

func world_to_grid_position(world_pos: Vector2) -> Vector2i:
	# Convert world coordinates back to grid coordinates with precise tile detection
	var tile_total_size = game_field.tile_size + game_field.tile_spacing
	
	# Find which tile the world position falls into by checking against each tile's actual bounds
	for x in range(game_field.grid_size):
		for y in range(game_field.grid_size):
			# Calculate tile's world boundaries
			var tile_world_pos = game_field.get_world_position(Vector2i(x, y))
			var tile_left = tile_world_pos.x - game_field.tile_size / 2.0
			var tile_right = tile_world_pos.x + game_field.tile_size / 2.0
			var tile_top = tile_world_pos.y - game_field.tile_size / 2.0
			var tile_bottom = tile_world_pos.y + game_field.tile_size / 2.0
			
			# Check if world position is within this tile's boundaries
			if world_pos.x >= tile_left and world_pos.x <= tile_right and world_pos.y >= tile_top and world_pos.y <= tile_bottom:
				print("World pos ", world_pos, " is within tile (", x, ", ", y, ") bounds")
				print("Tile bounds: left=", tile_left, " right=", tile_right, " top=", tile_top, " bottom=", tile_bottom)
				return Vector2i(x, y)
	
	# Fallback to mathematical conversion if no exact tile match found
	var target_x = int(world_pos.x / tile_total_size)
	var target_y = int(world_pos.y / tile_total_size)
	
	print("No exact tile match found, using fallback: (", target_x, ", ", target_y, ")")
	
	# Clamp to grid bounds
	target_x = clamp(target_x, 0, game_field.grid_size - 1)
	target_y = clamp(target_y, 0, game_field.grid_size - 1)
	
	return Vector2i(target_x, target_y)

func connect_to_tiles():
	# No longer needed with global input handling
	print("Using global input handling for tile clicks")

func handle_input():
	# Check if we're in battle mode - restrict movement during battle
	if game_field.is_in_battle:
		return
		
	# Arrow keys for direct movement (single step) including diagonal combinations
	if not is_moving:
		var move_x = 0
		var move_y = 0
		
		# Check horizontal movement
		if Input.is_action_just_pressed("ui_right"):
			move_x = 1
		elif Input.is_action_just_pressed("ui_left"):
			move_x = -1
		
		# Check vertical movement
		if Input.is_action_just_pressed("ui_down"):
			move_y = 1
		elif Input.is_action_just_pressed("ui_up"):
			move_y = -1
		
		# Apply movement if any direction was pressed
		if move_x != 0 or move_y != 0:
			move_single_step(Vector2i(grid_x + move_x, grid_y + move_y))

func move_single_step(target: Vector2i):
	# Direct single-step movement for arrow keys
	if is_moving:
		return
	
	# Check if target is walkable
	if not game_field.is_walkable_for_character(target.x, target.y, self):
		print("Cannot move to (", target.x, ", ", target.y, ") - blocked")
		return
	
	# Move directly without pathfinding
	is_moving = true
	grid_x = target.x
	grid_y = target.y
	
	# Update world position
	var new_pos = game_field.get_world_position(Vector2i(grid_x, grid_y))
	
	# Stop previous tween if exists
	if move_tween:
		move_tween.kill()
	
	# Smooth movement
	move_tween = create_tween()
	move_tween.tween_property(self, "position", new_pos, 0.15)
	move_tween.tween_callback(_on_single_move_completed)

func _on_single_move_completed():
	is_moving = false
	moved.emit(grid_x, grid_y)
	print("Player moved to (", grid_x, ", ", grid_y, ")")
	
	# Clear highlight if we reached the highlighted tile
	game_field.check_and_clear_highlight_on_arrival(Vector2i(grid_x, grid_y))
	
	# Check if we should enter/exit battle mode
	game_field.check_battle_state()

func move_to_position(target: Vector2i):
	print("=== MOVE TO POSITION START ===")
	print("Target: (", target.x, ", ", target.y, ")")
	print("Current position: (", grid_x, ", ", grid_y, ")")
	print("is_moving: ", is_moving)
	
	# Stop any existing movement first
	if is_moving:
		print("Stopping existing movement to start new one")
		stop_movement()
	
	# Check if we're already at the target
	if target.x == grid_x and target.y == grid_y:
		print("Already at target position")
		return
	
	# Check if target is walkable
	var walkable = game_field.is_walkable_for_character(target.x, target.y, self)
	print("Target walkable: ", walkable)
	if not walkable:
		print("Cannot move to (", target.x, ", ", target.y, ") - not walkable")
		return
	
	# Find path to target
	var start_pos = Vector2i(grid_x, grid_y)
	print("Finding path from (", start_pos.x, ", ", start_pos.y, ") to (", target.x, ", ", target.y, ")")
	current_path = game_field.find_path_for_character(start_pos, target, self)
	
	print("Pathfinding result - path length: ", current_path.size())
	if current_path.size() == 0:
		print("No path found to (", target.x, ", ", target.y, ")")
		return
	
	print("Path found: ", current_path)
	path_index = 0
	is_moving = true
	print("Starting path following...")
	follow_path()

func follow_loot_path(loot_path: Array[Vector2i]):
	"""Follow exact path through loot items (for battle mode loot collection)"""
	print("=== FOLLOW LOOT PATH START ===")
	print("Loot path: ", loot_path)
	
	# Stop any existing movement
	if is_moving:
		stop_movement()
	
	# Set the loot path as current path
	current_path = loot_path
	path_index = 0
	is_moving = true
	print("Starting loot path following...")
	follow_path()

func follow_path():
	if path_index >= current_path.size():
		# Path completed
		print("Path completed!")
		current_path.clear()
		path_index = 0
		is_moving = false
		path_completed.emit()
		return
	
	# Move to next position in path
	var next_pos = current_path[path_index]
	print("Following path step ", path_index, ": moving to (", next_pos.x, ", ", next_pos.y, ")")
	move_to_grid_direct(next_pos.x, next_pos.y)
	

func move_to_grid_direct(new_x: int, new_y: int):
	# Trigger loot collection at current position BEFORE moving (when leaving tile)
	if game_field.collecting_loot:
		game_field.collect_loot_at_position(Vector2i(grid_x, grid_y))
	
	# Direct movement for pathfinding (no validation needed as path is pre-validated)
	grid_x = new_x
	grid_y = new_y
	
	# Update world position
	var new_pos = game_field.get_world_position(Vector2i(grid_x, grid_y))
	
	# Stop previous tween if exists
	if move_tween:
		move_tween.kill()
	
	# Smooth movement
	move_tween = create_tween()
	move_tween.tween_property(self, "position", new_pos, 0.15)
	move_tween.tween_callback(_on_move_completed)

func _on_move_completed():
	# Move to next step in path
	path_index += 1
	moved.emit(grid_x, grid_y)
	print("Player moved to (", grid_x, ", ", grid_y, "), path_index: ", path_index, "/", current_path.size())
	
	# Check battle state after each movement step (but not when collecting loot)
	if not game_field.collecting_loot:
		game_field.check_battle_state()
		
		# If we entered battle mode, stop pathfinding
		if game_field.is_in_battle:
			print("Entered battle mode - stopping pathfinding")
			stop_movement()
			return
	
	# Check if we should continue (path might have been cancelled)
	if current_path.size() == 0:
		print("Path was cancelled during movement")
		is_moving = false
		return
	
	# Continue following the path automatically
	if path_index < current_path.size():
		follow_path()
	else:
		# Path completed - collect loot at final position
		if game_field.collecting_loot:
			game_field.collect_loot_at_position(Vector2i(grid_x, grid_y))
		
		print("Path fully completed!")
		# Clear highlight when pathfinding is complete
		game_field.check_and_clear_highlight_on_arrival(Vector2i(grid_x, grid_y))
		current_path.clear()
		path_index = 0
		is_moving = false
		path_completed.emit()

func try_open_combat_menu(_screen_pos: Vector2) -> bool:
	"""Try to open combat menu for adjacent enemy. Returns true if menu opened."""
	# Convert screen position to world position
	var camera = game_field.get_node("Camera2D")
	var world_pos = camera.get_global_mouse_position()
	var grid_pos = world_to_grid_position(world_pos)
	
	print("Right-click at grid position: (", grid_pos.x, ", ", grid_pos.y, ")")
	
	# Check if there's an enemy at this position
	for enemy in game_field.enemies:
		if enemy.grid_x == grid_pos.x and enemy.grid_y == grid_pos.y:
			# Check if enemy is adjacent to player
			var distance = abs(enemy.grid_x - grid_x) + abs(enemy.grid_y - grid_y)
			if distance == 1:  # Adjacent (orthogonal only)
				print("Opening combat menu for adjacent enemy")
				game_field.show_combat_menu(enemy)
				return true
			else:
				print("Enemy not adjacent (distance: ", distance, ")")
				return false
	
	print("No enemy found at clicked position")
	return false

func stop_movement():
	print("Stopping player movement")
	# Cancel current path
	current_path.clear()
	path_index = 0
	# Stop tween
	if move_tween:
		move_tween.kill()
		move_tween = null
	# Reset moving state
	is_moving = false
	# Clear highlight when stopping movement
	game_field.clear_highlight()

func set_grid_position(x: int, y: int):
	grid_x = x
	grid_y = y
	
	# Set initial world position
	var world_pos = game_field.get_world_position(Vector2i(grid_x, grid_y))
	position = world_pos
