extends Node2D

@export var grid_size: int = 10
@export var tile_size: int = 64
@export var tile_spacing: int = 2

var tile_scene = preload("res://Tile.tscn")
var player_scene = preload("res://Player.tscn")
var enemy_scene = preload("res://Enemy.tscn")
var obstacle_scene = preload("res://Obstacle.tscn")
var pathfinder = PathfinderGrid
var tiles: Array[Array] = []
var obstacles: Array[Array] = []  # 2D array to track obstacles
var grid_container: Node2D
var player: CharacterBody2D
var enemies: Array[CharacterBody2D] = []
var enemies_active: bool = false
var start_button: Button
# Enemy health system
var enemy_health: Dictionary = {}  # Maps enemy to current health
var max_enemy_health: int = 3      # Default enemy health

# Loot collection configuration
var loot_config: LootConfig
var pending_collections: Array[Dictionary] = []  # Queue of loot items to collect during movement
# Battle system variables
var is_in_battle: bool = false
var battle_participants: Array[CharacterBody2D] = []

# Loot system variables
var loot_items: Array[LootItem] = []

# Simplified loot system with one type per category (balanced basic level)
var loot_categories = {
	"weapons": ["sword"],
	"armor": ["shield"], 
	"potions": ["health_potion"],
	"currency": ["coin"],
	"enemies": ["goblin", "orc", "skeleton", "spider"]  # Keep variety for enemies
}

var loot_colors = {
	# Basic loot types (one per category)
	"sword": Color.SILVER,           # Weapons - Silver
	"shield": Color.BROWN,           # Armor - Brown
	"health_potion": Color.RED,      # Potions - Red
	"coin": Color.YELLOW,            # Currency - Yellow
	# Enemy variety (keep different colors for visual distinction)
	"goblin": Color(0.2, 0.6, 0.2, 1.0),    # Green
	"orc": Color(0.6, 0.2, 0.2, 1.0),       # Dark Red
	"skeleton": Color(0.9, 0.9, 0.9, 1.0),  # Light Gray
	"spider": Color(0.3, 0.1, 0.3, 1.0)     # Purple
}

# Get all possible loot types from all categories
func get_all_loot_types() -> Array[String]:
	var all_types: Array[String] = []
	for category in loot_categories.values():
		all_types.append_array(category)
	return all_types

# Get category of a loot type
func get_loot_category(loot_type: String) -> String:
	for category in loot_categories.keys():
		if loot_type in loot_categories[category]:
			return category
	return ""

# Match-3 loot selection system
var selected_loot_item: LootItem = null
var loot_chain: Array[LootItem] = []
var chain_lines: Array[Line2D] = []
var collecting_loot: bool = false
var is_selecting_loot: bool = false
var highlighted_tile: Node2D = null
var active_combat_menu: PopupPanel = null
var combat_target_enemy: CharacterBody2D = null

@onready var camera = $Camera2D

# Anti-deadlock system
var deadlock_check_timer: float = 0.0
var deadlock_check_interval: float = 5.0  # Check every 5 seconds
var last_player_position: Vector2i
var position_stuck_time: float = 0.0
var max_stuck_time: float = 10.0  # 10 seconds before intervention

func _ready():
	# Initialize loot configuration
	loot_config = LootConfig.new()
	
	grid_container = $GridContainer
	generate_grid()
	spawn_obstacles()
	spawn_player()
	spawn_enemies()
	center_camera()
	
	# Initialize anti-deadlock system
	last_player_position = Vector2i(player.grid_x, player.grid_y)

func _process(delta: float):
	"""Monitor for deadlock situations and provide automatic solutions"""
	deadlock_check_timer += delta
	
	if deadlock_check_timer >= deadlock_check_interval:
		deadlock_check_timer = 0.0
		check_for_deadlock_situation()

func check_for_deadlock_situation():
	"""Detect and resolve deadlock situations automatically"""
	var current_pos = Vector2i(player.grid_x, player.grid_y)
	
	# Check if player is stuck in same position
	if current_pos == last_player_position:
		position_stuck_time += deadlock_check_interval
		
		if position_stuck_time >= max_stuck_time:
			print("🚨 DEADLOCK DETECTED: Player stuck for ", position_stuck_time, " seconds")
			resolve_deadlock_situation(current_pos)
			position_stuck_time = 0.0
	else:
		# Player moved, reset timer
		position_stuck_time = 0.0
		last_player_position = current_pos
	
	# Additional checks for movement availability
	check_movement_options(current_pos)

func check_movement_options(player_pos: Vector2i):
	"""Check if player has sufficient movement and action options"""
	var available_moves = count_available_moves(player_pos)
	var available_actions = count_available_actions(player_pos)
	
	if available_moves < 2 and available_actions == 0:
		print("⚠️ LIMITED OPTIONS: Only ", available_moves, " moves, ", available_actions, " actions")
		if available_moves == 0:
			print("🆘 EMERGENCY: No movement options available!")
			resolve_deadlock_situation(player_pos)

func count_available_moves(pos: Vector2i) -> int:
	"""Count how many directions player can move"""
	var moves = 0
	var directions = [Vector2i(0,1), Vector2i(1,0), Vector2i(0,-1), Vector2i(-1,0)]
	
	for direction in directions:
		var check_pos = pos + direction
		if is_valid_grid_position(check_pos) and not is_position_blocked(check_pos):
			moves += 1
	
	return moves

func count_available_actions(pos: Vector2i) -> int:
	"""Count available actions (combat, loot collection, etc.)"""
	var actions = 0
	
	# Check for adjacent enemies (combat options)
	for enemy in enemies:
		var distance = abs(enemy.grid_x - pos.x) + abs(enemy.grid_y - pos.y)
		if distance == 1:
			actions += 1
	
	# Check for nearby loot (collection options)
	var nearby_loot = 0
	for loot in loot_items:
		if is_instance_valid(loot):
			var distance = abs(loot.grid_x - pos.x) + abs(loot.grid_y - pos.y)
			if distance <= 2:  # Within reasonable reach
				nearby_loot += 1
	
	actions += min(nearby_loot, 3)  # Cap loot actions for calculation
	return actions

func resolve_deadlock_situation(player_pos: Vector2i):
	"""Automatically resolve deadlock by creating escape routes and opportunities"""
	print("🔧 RESOLVING DEADLOCK at position (", player_pos.x, ", ", player_pos.y, ")")
	
	# Solution 1: Clear escape routes
	create_escape_routes(player_pos)
	
	# Solution 2: Add strategic loot for collection opportunities  
	add_emergency_loot(player_pos)
	
	# Solution 3: Reposition problematic enemies
	reposition_blocking_enemies(player_pos)
	
	print("✅ Deadlock resolution completed")

func create_escape_routes(center_pos: Vector2i):
	"""Clear loot items around player to create movement corridors"""
	var cleared_count = 0
	
	# Clear 3x3 area around player
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue  # Skip player position
			
			var check_pos = center_pos + Vector2i(x_offset, y_offset)
			
			# Remove any loot at this position
			for i in range(loot_items.size() - 1, -1, -1):
				var loot = loot_items[i]
				if is_instance_valid(loot) and Vector2i(loot.grid_x, loot.grid_y) == check_pos:
					loot.queue_free()
					loot_items.remove_at(i)
					cleared_count += 1
	
	print("Cleared ", cleared_count, " loot items to create escape routes")

func add_emergency_loot(center_pos: Vector2i):
	"""Add collectible loot nearby to give player action options"""
	var directions = [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	var added_count = 0
	
	for direction in directions:
		var loot_pos = center_pos + direction
		
		if is_valid_grid_position(loot_pos) and not is_position_blocked(loot_pos):
			# Add easy-to-collect loot
			create_loot_item_at_position("coin", loot_pos)
			added_count += 1
			
			if added_count >= 2:  # Limit emergency loot
				break
	
	print("Added ", added_count, " emergency loot items")

func reposition_blocking_enemies(center_pos: Vector2i):
	"""Move enemies that might be blocking player movement"""
	var repositioned_count = 0
	
	for enemy in enemies:
		var distance = abs(enemy.grid_x - center_pos.x) + abs(enemy.grid_y - center_pos.y)
		
		# If enemy is too close and potentially blocking
		if distance <= 2:
			var new_pos = find_safe_enemy_position(center_pos, enemy)
			if new_pos != Vector2i(-1, -1):
				enemy.grid_x = new_pos.x
				enemy.grid_y = new_pos.y
				enemy.position = get_world_position(new_pos)
				repositioned_count += 1
	
	print("Repositioned ", repositioned_count, " blocking enemies")

func find_safe_enemy_position(avoid_center: Vector2i, enemy: CharacterBody2D) -> Vector2i:
	"""Find a safe position for enemy away from player"""
	for attempt in range(20):  # Try 20 random positions
		var new_pos = Vector2i(
			randi_range(1, grid_size - 2),
			randi_range(1, grid_size - 2)
		)
		
		var distance_from_player = abs(new_pos.x - avoid_center.x) + abs(new_pos.y - avoid_center.y)
		
		# Position must be far enough and valid
		if distance_from_player >= 4 and not is_position_blocked(new_pos):
			return new_pos
	
	return Vector2i(-1, -1)  # No safe position found
	
	# Connect start button and setup UI
	var button_path = "UI/ControlPanel/ControlContainer/StartButton"
	var button_node = get_node_or_null(button_path)
	if button_node:
		print("Found button at path: ", button_path)
		print("Button type: ", button_node.get_class())
		print("Button text: ", button_node.text)
		
		# Try connecting the signal
		if not button_node.pressed.is_connected(_on_start_button_pressed):
			button_node.pressed.connect(_on_start_button_pressed)
			print("Button signal connected successfully")
		else:
			print("Button signal was already connected")
		
		start_button = button_node
	else:
		print("ERROR: Start button not found at path: ", button_path)
	
	# Initialize battle state UI
	update_battle_ui()

func generate_grid():
	# Initialize the 2D arrays
	tiles.resize(grid_size)
	obstacles.resize(grid_size)
	for i in range(grid_size):
		tiles[i] = []
		tiles[i].resize(grid_size)
		obstacles[i] = []
		obstacles[i].resize(grid_size)
	
	# Create tiles
	for x in range(grid_size):
		for y in range(grid_size):
			create_tile(x, y)

func create_tile(x: int, y: int):
	var tile_instance = tile_scene.instantiate()
	
	# Set position - center the tile properly
	var pos_x = x * (tile_size + tile_spacing) + tile_size / 2.0
	var pos_y = y * (tile_size + tile_spacing) + tile_size / 2.0
	tile_instance.position = Vector2(pos_x, pos_y)
	
	# Set grid coordinates
	tile_instance.set_grid_position(x, y)
	
	# Add to scene and store reference
	grid_container.add_child(tile_instance)
	tiles[x][y] = tile_instance

func center_camera():
	# Calculate the center of the grid
	var grid_width = (grid_size - 1) * (tile_size + tile_spacing)
	var grid_height = (grid_size - 1) * (tile_size + tile_spacing)
	var center_pos = Vector2(grid_width / 2.0, grid_height / 2.0)
	camera.position = center_pos

func get_tile(x: int, y: int):
	if x >= 0 and x < grid_size and y >= 0 and y < grid_size:
		return tiles[x][y]
	return null

func spawn_player():
	player = player_scene.instantiate()
	add_child(player)
	
	# Place player at top-left corner
	player.set_grid_position(0, 0)
	print("Player spawned at (0, 0)")

func spawn_enemies():
	# Spawn 3 enemies at different positions
	var enemy_positions = [
		Vector2i(9, 0),  # Top-right
		Vector2i(0, 9),  # Bottom-left  
		Vector2i(9, 9)   # Bottom-right
	]
	
	for i in range(3):
		var enemy = enemy_scene.instantiate()
		add_child(enemy)
		
		var pos = enemy_positions[i]
		enemy.set_grid_position(pos.x, pos.y)
		enemy.set_player_reference(player)
		
		enemies.append(enemy)
		# Initialize enemy health
		enemy_health[enemy] = max_enemy_health
		print("Enemy ", i + 1, " spawned at (", pos.x, ", ", pos.y, ") with ", max_enemy_health, " health")

func spawn_obstacles():
	# Create some sample obstacles
	var obstacle_positions = [
		{"pos": Vector2i(3, 3), "type": Obstacle.ObstacleType.WALL},
		{"pos": Vector2i(4, 3), "type": Obstacle.ObstacleType.WALL},
		{"pos": Vector2i(5, 3), "type": Obstacle.ObstacleType.INTERACTIVE},
		{"pos": Vector2i(7, 7), "type": Obstacle.ObstacleType.DESTRUCTIBLE},
		{"pos": Vector2i(8, 2), "type": Obstacle.ObstacleType.TRAP},
		{"pos": Vector2i(6, 5), "type": Obstacle.ObstacleType.WALL},
		{"pos": Vector2i(1, 5), "type": Obstacle.ObstacleType.INTERACTIVE}
	]
	
	for obstacle_data in obstacle_positions:
		create_obstacle(obstacle_data.pos.x, obstacle_data.pos.y, obstacle_data.type)

func create_obstacle(x: int, y: int, type: Obstacle.ObstacleType):
	var obstacle_instance = obstacle_scene.instantiate()
	
	# Set position
	var world_pos = get_world_position(Vector2i(x, y))
	obstacle_instance.position = world_pos
	
	# Set properties
	obstacle_instance.set_grid_position(x, y)
	obstacle_instance.obstacle_type = type
	
	# Configure based on type
	match type:
		Obstacle.ObstacleType.INTERACTIVE:
			obstacle_instance.is_passable = false  # Start closed
		Obstacle.ObstacleType.DESTRUCTIBLE:
			obstacle_instance.health = 3
		Obstacle.ObstacleType.TRAP:
			obstacle_instance.damage = 1
			obstacle_instance.is_passable = true  # Hidden traps
	
	# Connect signals
	obstacle_instance.obstacle_destroyed.connect(_on_obstacle_destroyed)
	obstacle_instance.obstacle_interacted.connect(_on_obstacle_interacted)
	
	# Add to scene and store reference
	grid_container.add_child(obstacle_instance)
	obstacles[x][y] = obstacle_instance
	
	print("Created ", Obstacle.ObstacleType.keys()[type], " obstacle at (", x, ", ", y, ")")

func _on_obstacle_destroyed(obstacle: Obstacle):
	print("Obstacle destroyed at (", obstacle.grid_x, ", ", obstacle.grid_y, ")")
	obstacles[obstacle.grid_x][obstacle.grid_y] = null

func _on_obstacle_interacted(_obstacle: Obstacle, interactor: CharacterBody2D):
	var interactor_name = "unknown"
	if interactor:
		interactor_name = interactor.name
	print("Obstacle interacted with by ", interactor_name)

func remove_obstacle(obstacle: Obstacle):
	if obstacle.grid_x >= 0 and obstacle.grid_x < grid_size and obstacle.grid_y >= 0 and obstacle.grid_y < grid_size:
		obstacles[obstacle.grid_x][obstacle.grid_y] = null

func get_obstacle(x: int, y: int) -> Obstacle:
	if x >= 0 and x < grid_size and y >= 0 and y < grid_size:
		return obstacles[x][y]
	return null

func is_position_occupied_by_character(x: int, y: int) -> bool:
	# Check if player is at position
	if player and player.grid_x == x and player.grid_y == y:
		return true
	
	# Check if any enemy is at position
	for enemy in enemies:
		if enemy.grid_x == x and enemy.grid_y == y:
			return true
	
	return false

func is_walkable(x: int, y: int) -> bool:
	# Check bounds
	if x < 0 or x >= grid_size or y < 0 or y >= grid_size:
		return false
	
	# Check if tile is occupied
	var tile = get_tile(x, y)
	if tile and tile.is_occupied:
		return false
	
	return true

func is_walkable_for_character(x: int, y: int, moving_character: CharacterBody2D) -> bool:
	# Check bounds
	if x < 0 or x >= grid_size or y < 0 or y >= grid_size:
		return false
	
	# Check if tile is occupied
	var tile = get_tile(x, y)
	if tile and tile.is_occupied:
		return false
	
	# Check obstacles
	var obstacle = get_obstacle(x, y)
	if obstacle and obstacle.blocks_movement():
		return false
	
	# Check if another character is at position (excluding the moving character)
	if player and player != moving_character and player.grid_x == x and player.grid_y == y:
		return false
	
	for enemy in enemies:
		if enemy != moving_character and enemy.grid_x == x and enemy.grid_y == y:
			return false
	
	return true

func find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	return pathfinder.find_path(start, end, Vector2i(grid_size, grid_size), is_walkable)

func find_path_for_character(start: Vector2i, end: Vector2i, character: CharacterBody2D) -> Array[Vector2i]:
	var walkable_func = func(x: int, y: int) -> bool:
		return is_walkable_for_character(x, y, character)
	return pathfinder.find_path(start, end, Vector2i(grid_size, grid_size), walkable_func)

func get_world_position(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * (tile_size + tile_spacing) + tile_size / 2.0,
		grid_pos.y * (tile_size + tile_spacing) + tile_size / 2.0
	)

# Match-3 Loot System Functions
func start_loot_selection(mouse_pos: Vector2):
	"""Start loot selection when left mouse button is pressed"""
	print("Attempting loot selection at: ", mouse_pos)
	# Convert screen coordinates to world coordinates
	var world_mouse_pos = camera.get_global_mouse_position()
	var clicked_item = get_loot_item_at_mouse(world_mouse_pos)
	
	if clicked_item:
		# Check if clicked item is adjacent to player
		var player_pos = Vector2i(player.grid_x, player.grid_y)
		var loot_pos = Vector2i(clicked_item.grid_x, clicked_item.grid_y)
		var dx = abs(player_pos.x - loot_pos.x)
		var dy = abs(player_pos.y - loot_pos.y)
		
		if dx <= 1 and dy <= 1 and (dx + dy) > 0:  # Adjacent to player
			print("Found loot item: ", clicked_item.loot_type, " at (", clicked_item.grid_x, ", ", clicked_item.grid_y, ")")
			is_selecting_loot = true
			selected_loot_item = clicked_item
			build_loot_chain(selected_loot_item)
		else:
			print("Loot item not adjacent to player - cannot select")
			return  # Exit early if item not adjacent
		update_loot_chain_visuals()
		print("Started selecting ", selected_loot_item.loot_type, " chain")
	else:
		print("No loot item found at mouse position")

func update_loot_selection(mouse_pos: Vector2):
	"""Update loot chain while mouse button is held down with backtrace support"""
	# Early exit if no loot item is selected
	if not selected_loot_item:
		return
	
	# Convert screen coordinates to world coordinates
	var world_mouse_pos = camera.get_global_mouse_position()
	var current_item = get_loot_item_at_mouse(world_mouse_pos)
	
	if current_item:
		# Check if current item is already in the chain (backtrace)
		var item_index_in_chain = loot_chain.find(current_item)
		
		if item_index_in_chain != -1:
			# Backtrace: Remove all items after this index
			print("Backtrace detected - removing items after index ", item_index_in_chain)
			var items_to_remove = loot_chain.size() - (item_index_in_chain + 1)
			
			# Clear highlights on items that will be removed
			for i in range(item_index_in_chain + 1, loot_chain.size()):
				var item_to_remove = loot_chain[i]
				if is_instance_valid(item_to_remove):
					item_to_remove.set_chain_highlight(false)
					print("Cleared highlight for ", item_to_remove.loot_type)
			
			# Remove items from the end
			for i in range(items_to_remove):
				var removed_item = loot_chain.pop_back()
				print("Removed ", removed_item.loot_type, " from chain")
			
			update_loot_chain_visuals()
			print("Chain after backtrace, size: ", loot_chain.size())
			
		elif can_chain_items(selected_loot_item, current_item):
			# Forward selection: Check if this item is adjacent to the last item in chain
			var last_item = loot_chain[-1] if loot_chain.size() > 0 else selected_loot_item
			if is_adjacent_loot(current_item, last_item) and current_item not in loot_chain:
				# Add to chain if adjacent and not already in chain
				loot_chain.append(current_item)
				update_loot_chain_visuals()
				print("Added ", current_item.loot_type, " to chain, size: ", loot_chain.size())

func end_loot_selection():
	"""End loot selection when left mouse button is released"""
	if is_selecting_loot:
		print("Ending selection, chain size: ", loot_chain.size())
		if loot_chain.size() >= 3:
			# Check if this is a damage chain (weapons + enemies)
			if is_damage_chain(loot_chain):
				process_damage_chain(loot_chain)
			else:
				collect_loot_chain()
		else:
			print("Need at least 3 connected loot items to collect")
			clear_loot_chain_visuals()
			loot_chain.clear()
		
		is_selecting_loot = false
		selected_loot_item = null

func is_damage_chain(chain: Array[LootItem]) -> bool:
	"""Check if chain contains both weapons and enemies"""
	var has_weapon = false
	var has_enemy = false
	
	for item in chain:
		var category = get_loot_category(item.loot_type)
		if category == "weapons":
			has_weapon = true
		elif category == "enemies":
			has_enemy = true
	
	return has_weapon and has_enemy

func process_damage_chain(chain: Array[LootItem]):
	"""Process a damage chain - enemies take damage, loot is collected"""
	print("Processing damage chain with ", chain.size(), " items")
	collecting_loot = true
	
	# Move player through the chain path
	if is_in_battle:
		var loot_path: Array[Vector2i] = []
		for loot in chain:
			loot_path.append(Vector2i(loot.grid_x, loot.grid_y))
		player.follow_loot_path(loot_path)
		await player.path_completed
	else:
		var target_pos = Vector2i(chain[-1].grid_x, chain[-1].grid_y)
		player.move_to_position(target_pos)
		await player.path_completed
	
	# Prepare chain items for progressive collection (don't process immediately)
	pending_collections.clear()
	for loot in chain:
		if is_instance_valid(loot):
			var collection_data = {
				"loot_item": loot,
				"position": Vector2i(loot.grid_x, loot.grid_y),
				"category": get_loot_category(loot.loot_type),
				"collected": false
			}
			pending_collections.append(collection_data)
	
	print("Prepared ", pending_collections.size(), " items for progressive collection")
	
	# Clear visuals and chain but keep loot items until collected during movement
	clear_loot_chain_visuals()
	loot_chain.clear()
	# Note: collecting_loot remains true until all items are collected

func deal_damage_to_enemy_loot(enemy_loot: LootItem) -> int:
	"""Deal damage to enemy through loot item, return damage dealt"""
	var damage = 1  # Standard weapon damage
	
	if enemy_loot.has_method("get") and "original_enemy" in enemy_loot:
		var enemy = enemy_loot.original_enemy
		if is_instance_valid(enemy) and enemy in enemy_health:
			# Apply damage
			enemy_health[enemy] -= damage
			print("Enemy health: ", enemy_health[enemy], "/", max_enemy_health)
			
			# Check if enemy died
			if enemy_health[enemy] <= 0:
				print("Enemy has died!")
				# Remove from enemies array and game
				enemies.erase(enemy)
				enemy_health.erase(enemy)
				if is_instance_valid(enemy):
					enemy.queue_free()
			
			return damage
	
	return 0

func collect_loot_at_position(pos: Vector2i):
	"""Collect loot item at specific position during player movement"""
	print("Checking for loot collection at (", pos.x, ", ", pos.y, ")")
	
	# Find pending collection at this position
	for i in range(pending_collections.size()):
		var collection_data = pending_collections[i]
		if not collection_data.collected and collection_data.position == pos:
			# Validate loot item is still valid before accessing properties
			if not is_instance_valid(collection_data.loot_item):
				print("Loot item at position was freed, skipping collection")
				continue
			print("Found loot to collect: ", collection_data.loot_item.loot_type)
			
			# Mark as collected
			collection_data.collected = true
			
			# Calculate progressive delay for comet tail effect
			# Items collected earlier get slightly longer delays
			var collected_count = 0
			for data in pending_collections:
				if data.collected:
					collected_count += 1
			
			var progressive_delay = loot_config.collection_delay + (collected_count * 0.05)  # 0.05s per item
			print("Using progressive delay: ", progressive_delay, "s (item #", collected_count, ")")
			
			# Start collection with progressive delay
			var timer = get_tree().create_timer(progressive_delay)
			timer.timeout.connect(_process_loot_collection.bind(collection_data))
			
			break
	
	# Check if all collections are complete
	_check_collection_completion()

func _process_loot_collection(collection_data: Dictionary):
	"""Process individual loot item collection with animation"""
	var loot = collection_data.loot_item
	var category = collection_data.category
	
	if not is_instance_valid(loot):
		print("Loot item was freed, skipping collection")
		return
	
	print("Processing collection of ", loot.loot_type)
	
	# Handle different categories
	if category == "enemies":
		# Enemy takes damage
		var damage_dealt = deal_damage_to_enemy_loot(loot)
		if is_instance_valid(loot):
			print("Enemy ", loot.loot_type, " takes ", damage_dealt, " damage!")
		create_damage_effect(loot.position)
	else:
		# Regular loot collection
		if is_instance_valid(loot):
			print("Collected ", loot.loot_type)
		if loot_config.highlight_collected_tiles:
			highlight_collection_tile(collection_data.position)
	
	# Create collection animation
	_animate_loot_collection(loot)
	
	# Signal collection
	_on_loot_item_collected(loot)

func _animate_loot_collection(loot: LootItem):
	"""Animate loot item disappearance with comet tail effect"""
	if not is_instance_valid(loot):
		return
	
	# Create smooth comet tail fade effect
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	
	# Multi-stage fade for comet tail effect
	# Stage 1: Quick initial fade (simulate player "picking up")
	tween.parallel().tween_property(loot, "modulate:a", 0.7, loot_config.collection_animation_time * 0.2)
	tween.parallel().tween_property(loot, "scale", Vector2(loot_config.collection_effect_scale * 0.9, loot_config.collection_effect_scale * 0.9), loot_config.collection_animation_time * 0.2)
	
	# Stage 2: Gradual trail fade (comet tail)
	tween.parallel().tween_property(loot, "modulate:a", 0.3, loot_config.collection_animation_time * 0.5)
	tween.parallel().tween_property(loot, "scale", Vector2(loot_config.collection_effect_scale, loot_config.collection_effect_scale), loot_config.collection_animation_time * 0.5)
	
	# Stage 3: Final disappearance
	tween.parallel().tween_property(loot, "modulate:a", 0.0, loot_config.collection_animation_time * 0.3)
	tween.parallel().tween_property(loot, "scale", Vector2(loot_config.collection_effect_scale * 1.1, loot_config.collection_effect_scale * 1.1), loot_config.collection_animation_time * 0.3)
	
	tween.tween_callback(loot.queue_free)

func highlight_collection_tile(pos: Vector2i):
	"""Briefly highlight the tile where loot was collected"""
	var tile = get_tile(pos.x, pos.y)
	if tile and tile.has_method("set_highlighted"):
		tile.set_highlighted(true)
		# Remove highlight after duration
		var timer = get_tree().create_timer(loot_config.highlight_duration)
		timer.timeout.connect(func(): tile.set_highlighted(false))

func _check_collection_completion():
	"""Check if all loot collection is complete"""
	var all_collected = true
	for collection_data in pending_collections:
		if not collection_data.collected:
			all_collected = false
			break
	
	if all_collected and pending_collections.size() > 0:
		print("All loot collection completed!")
		pending_collections.clear()
		collecting_loot = false

func create_damage_effect(pos: Vector2):
	"""Create visual damage effect at position"""
	var damage_effect = ColorRect.new()
	damage_effect.size = Vector2(64, 64)
	damage_effect.position = pos - Vector2(32, 32)
	damage_effect.color = Color.RED
	add_child(damage_effect)
	
	# Animate the effect
	var tween = create_tween()
	tween.parallel().tween_property(damage_effect, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(damage_effect, "scale", Vector2(2.0, 2.0), 0.5)
	tween.tween_callback(damage_effect.queue_free)

func get_loot_item_at_mouse(mouse_pos: Vector2) -> LootItem:
	"""Find loot item at mouse position"""
	print("Looking for loot at world position: ", mouse_pos)
	for loot in loot_items:
		var loot_rect = Rect2(loot.position - Vector2(32, 32), Vector2(64, 64))
		if loot_rect.has_point(mouse_pos):
			print("Found loot: ", loot.loot_type, " at ", loot.position)
			return loot
	return null

func build_loot_chain(start_item: LootItem):
	"""Initialize chain with starting item"""
	loot_chain.clear()
	loot_chain.append(start_item)

func can_chain_items(item1: LootItem, item2: LootItem) -> bool:
	"""Check if two loot items can be chained together"""
	var cat1 = get_loot_category(item1.loot_type)
	var cat2 = get_loot_category(item2.loot_type)
	
	# Same category items can always chain
	if cat1 == cat2:
		return true
	
	# Weapons can chain with enemies (for damage)
	if (cat1 == "weapons" and cat2 == "enemies") or (cat1 == "enemies" and cat2 == "weapons"):
		return true
	
	# No other cross-category chaining allowed
	return false

func is_adjacent_loot(item1: LootItem, item2: LootItem) -> bool:
	"""Check if two loot items are adjacent (8-directional)"""
	var dx = abs(item1.grid_x - item2.grid_x)
	var dy = abs(item1.grid_y - item2.grid_y)
	return dx <= 1 and dy <= 1 and (dx + dy) > 0  # Adjacent but not same position

func get_loot_item_at_grid(grid_pos: Vector2i) -> LootItem:
	"""Find loot item at specific grid position"""
	for loot in loot_items:
		if loot.grid_x == grid_pos.x and loot.grid_y == grid_pos.y:
			return loot
	return null

func update_loot_chain_visuals():
	"""Update visual representation of loot chain"""
	clear_loot_chain_visuals()
	
	# Always show visuals for any chain size > 0
	if loot_chain.size() == 0:
		return
	
	# Add green borders to chained items
	for loot in loot_chain:
		loot.set_chain_highlight(true)
	
	# Draw red line following the exact player selection path
	if loot_chain.size() > 0:
		var line = Line2D.new()
		line.default_color = Color.RED
		line.width = 3
		line.z_index = 10
		
		# Line from player to first selected item
		var player_pos = get_world_position(Vector2i(player.grid_x, player.grid_y))
		line.add_point(player_pos)
		line.add_point(loot_chain[0].position)
		
		# Lines connecting items in the exact order player selected them
		for i in range(1, loot_chain.size()):
			line.add_point(loot_chain[i].position)
		
		add_child(line)
		chain_lines.append(line)

func clear_loot_chain_visuals():
	"""Clear all loot chain visual effects"""
	# Remove green borders
	for loot in loot_chain:
		if is_instance_valid(loot):
			loot.set_chain_highlight(false)
	
	# Remove red lines
	for line in chain_lines:
		if is_instance_valid(line):
			line.queue_free()
	chain_lines.clear()

func collect_loot_chain():
	"""Collect the current loot chain using progressive collection system"""
	if loot_chain.size() < 3:
		return
	
	if loot_chain.size() > 0 and is_instance_valid(loot_chain[0]):
		print("Collecting chain of ", loot_chain.size(), " ", loot_chain[0].loot_type, " items")
	else:
		print("Collecting chain of ", loot_chain.size(), " items")
	collecting_loot = true
	
	# Prepare chain items for progressive collection (same as damage chains)
	pending_collections.clear()
	for loot in loot_chain:
		if is_instance_valid(loot):
			var collection_data = {
				"loot_item": loot,
				"position": Vector2i(loot.grid_x, loot.grid_y),
				"category": get_loot_category(loot.loot_type),
				"collected": false
			}
			pending_collections.append(collection_data)
	
	print("Prepared ", pending_collections.size(), " items for progressive collection")
	
	# Move player through the chain path
	if is_in_battle:
		var loot_path: Array[Vector2i] = []
		for loot in loot_chain:
			loot_path.append(Vector2i(loot.grid_x, loot.grid_y))
		player.follow_loot_path(loot_path)
		await player.path_completed
	else:
		var target_pos = Vector2i(loot_chain[-1].grid_x, loot_chain[-1].grid_y)
		player.move_to_position(target_pos)
		await player.path_completed
	
	# Clear visuals and chain but keep loot items until collected during movement
	clear_loot_chain_visuals()
	loot_chain.clear()
	# Note: collecting_loot remains true until all items are collected

func _input(event):
	# Handle UI clicks first to prevent them from reaching the player
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Note: PopupPanel will handle its own click detection and auto-close when clicking outside
		# No need to manually handle combat menu clicks here
		
		# PRIORITY 2: Check if click is on UI panels
		var info_panel = $UI/InfoPanel
		var control_panel = $UI/ControlPanel
		
		print("Click at: ", event.position)
		print("InfoPanel rect: ", info_panel.get_rect())
		print("ControlPanel rect: ", control_panel.get_rect())
		
		# Only consume event if it's NOT on an interactive UI element (button)
		# Let buttons handle their own events first
		var on_info_panel = info_panel.get_rect().has_point(event.position)
		var _on_control_panel = control_panel.get_rect().has_point(event.position)
		
		if on_info_panel:
			# Info panel doesn't have interactive elements, consume the event
			print("Click on InfoPanel, consuming event")
			get_viewport().set_input_as_handled()
			return
		# Don't consume control panel clicks - let buttons handle them
	
	# Camera controls
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom /= 1.1
			
	# Pan camera with middle mouse button
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		camera.position -= event.relative / camera.zoom
	
	# Match-3 loot selection during battle mode
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and is_in_battle and not collecting_loot:
		if event.pressed:
			# Start loot selection
			start_loot_selection(event.position)
		else:
			# End loot selection
			end_loot_selection()
	
	# Update loot chain while holding mouse button
	if event is InputEventMouseMotion and is_selecting_loot and is_in_battle and not collecting_loot:
		update_loot_selection(event.position)
	
	# DEBUG: Test battle mode with 'B' key
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		print("=== B KEY PRESSED - TESTING BATTLE MODE ===")
		if not is_in_battle:
			enter_battle_mode(enemies)
		else:
			exit_battle_mode()

func _on_start_button_pressed():
	print("=== BUTTON PRESSED ===")
	print("Current enemies_active: ", enemies_active)
	enemies_active = !enemies_active
	print("New enemies_active: ", enemies_active)
	start_button.text = "Stop" if enemies_active else "Start"
	print("Button text changed to: ", start_button.text)
	
	# Update all enemies
	print("Updating ", enemies.size(), " enemies")
	for enemy in enemies:
		enemy.set_active(enemies_active)
		print("Enemy ", enemy.name, " set to active: ", enemies_active)
	
	# Reset battle state when stopping enemies
	if not enemies_active:
		exit_battle_mode()
	
	print("Enemies ", "activated" if enemies_active else "deactivated")
	print("=== BUTTON HANDLER COMPLETE ===")

func check_battle_state():
	"""Check if player should enter or exit battle mode"""
	if not enemies_active:
		return
		
	var adjacent_enemies = get_adjacent_enemies(player)
	
	if adjacent_enemies.size() > 0 and not is_in_battle:
		# Enter battle mode
		enter_battle_mode(adjacent_enemies)
	elif adjacent_enemies.size() == 0 and is_in_battle:
		# Exit battle mode
		exit_battle_mode()

func get_adjacent_enemies(character: CharacterBody2D) -> Array[CharacterBody2D]:
	"""Get all enemies adjacent to the given character"""
	var adjacent = []
	var char_pos = character.get_grid_position()
	
	# Check all 4 adjacent positions (no diagonals for battle)
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	
	for dir in directions:
		var check_pos = char_pos + dir
		for enemy in enemies:
			if enemy.get_grid_position() == check_pos:
				adjacent.append(enemy)
				break
	
	return adjacent

func enter_battle_mode(adjacent_enemies: Array[CharacterBody2D]):
	"""Enter battle mode with specified enemies"""
	print("=== ENTERING BATTLE MODE ===")
	print("Enemies array size: ", adjacent_enemies.size())
	for i in range(adjacent_enemies.size()):
		print("Enemy ", i, ": ", adjacent_enemies[i])
	
	print("Setting is_in_battle to true")
	is_in_battle = true
	print("is_in_battle is now: ", is_in_battle)
	
	battle_participants.clear()
	battle_participants.append(player)
	battle_participants.append_array(adjacent_enemies)
	print("Battle participants: ", battle_participants.size())
	
	# Stop all character movement
	player.stop_movement()
	for enemy in adjacent_enemies:
		enemy.stop_movement()
	
	print("Battle participants: ", battle_participants.size())
	print("Player vs ", adjacent_enemies.size(), " enemies")
	
	# Update UI
	update_battle_ui()
	
	# Drop loot around all enemies when battle starts
	drop_loot_around_enemies()
	
	# TODO: Implement turn-based battle system here
	# For now, battle will auto-resolve after 3 seconds
	print("Creating battle timer for 3 seconds...")
	get_tree().create_timer(30.0).timeout.connect(auto_resolve_battle)
	print("Battle timer started, waiting for timeout...")

func auto_resolve_battle():
	"""Temporary auto-resolution for battle mode demo"""
	print("=== AUTO RESOLVE BATTLE CALLED ===")
	print("Current battle state: ", is_in_battle)
	print("Current loot items: ", loot_items.size())
	print("About to call exit_battle_mode()")
	exit_battle_mode()
	print("exit_battle_mode() completed")

func exit_battle_mode():
	"""Exit battle mode and return to exploration"""
	if not is_in_battle:
		return
		
	print("=== EXITING BATTLE MODE ===")
	is_in_battle = false
	battle_participants.clear()
	
	# Clean up loot items (for now - later could be persistent)
	clear_all_loot()
	
	# Resume normal movement for all characters
	for enemy in enemies:
		if enemy.has_method("resume_movement"):
			enemy.resume_movement()
	
	# Update UI
	update_battle_ui()
	
	print("Returned to exploration mode")

func _on_loot_item_collected(loot_item: LootItem):
	"""Handle when a loot item is collected by the player"""
	print("Player collected: ", loot_item.loot_type)
	# Remove from tracking array
	loot_items.erase(loot_item)
	# TODO: Add item to player inventory

func clear_all_loot():
	"""Remove all loot items from the field and restore living enemies"""
	print("=== CLEARING LOOT ===")
	print("Loot items to clear: ", loot_items.size())
	
	# Clear pending collections to avoid accessing freed loot items
	pending_collections.clear()
	print("Cleared pending collections to prevent freed object access")
	
	# Clear loot chain visuals (red lines) and selection state
	clear_loot_chain_visuals()
	loot_chain.clear()
	selected_loot_item = null
	print("Cleared loot chain visuals and selection state")
	
	var cleared_count = 0
	var restored_enemies = 0
	
	for loot in loot_items:
		if is_instance_valid(loot):
			# Check if this is an enemy loot item with a living enemy
			if loot.has_method("get") and "original_enemy" in loot:
				var enemy = loot.original_enemy
				if is_instance_valid(enemy) and enemy_health.get(enemy, 0) > 0:
					# Enemy is still alive, restore it
					enemy.visible = true
					restored_enemies += 1
					print("Restored enemy with ", enemy_health[enemy], " health")
			
			loot.queue_free()
			cleared_count += 1
		else:
			print("Invalid loot item found")
	
	loot_items.clear()
	print("Cleared ", cleared_count, " loot items")
	print("Restored ", restored_enemies, " living enemies")
	print("Loot array size after clear: ", loot_items.size())

func highlight_tile(grid_pos: Vector2i):
	"""Highlight a tile with yellow border"""
	print("=== HIGHLIGHT_TILE CALLED ===")
	print("Grid position: ", grid_pos)
	print("Grid size: ", grid_size)
	
	# Clear previous highlight
	clear_highlight()
	
	# Check if position is valid
	if grid_pos.x >= 0 and grid_pos.x < grid_size and grid_pos.y >= 0 and grid_pos.y < grid_size:
		print("Position is valid, checking walkability...")
		
		# Debug: Check what's at this position
		var tile_contents = get_tile_contents(grid_pos.x, grid_pos.y)
		print("Tile (", grid_pos.x, ", ", grid_pos.y, ") contents: ", tile_contents)
		
		# Only highlight walkable tiles
		if not is_walkable_for_character(grid_pos.x, grid_pos.y, player):
			print("Tile at (", grid_pos.x, ", ", grid_pos.y, ") is not walkable - no highlight")
			return
		
		if tiles.size() > grid_pos.x and tiles[grid_pos.x].size() > grid_pos.y:
			highlighted_tile = tiles[grid_pos.x][grid_pos.y]
			print("Found walkable tile: ", highlighted_tile)
			if highlighted_tile and highlighted_tile.has_method("set_highlighted"):
				highlighted_tile.set_highlighted(true)
				print("Highlighted walkable tile at (", grid_pos.x, ", ", grid_pos.y, ")")
			else:
				print("ERROR: Tile doesn't have set_highlighted method or is null")
		else:
			print("ERROR: Tiles array out of bounds")
	else:
		print("ERROR: Position out of grid bounds")

func get_tile_contents(x: int, y: int) -> String:
	"""Debug function to see what's on a tile"""
	var contents = []
	
	# Check for player
	if player and player.grid_x == x and player.grid_y == y:
		contents.append("player")
	
	# Check for enemies
	for enemy in enemies:
		if enemy.grid_x == x and enemy.grid_y == y:
			contents.append("enemy")
	
	# Check for obstacles
	if obstacles.size() > x and obstacles[x].size() > y and obstacles[x][y] != null:
		var obstacle = obstacles[x][y]
		contents.append("obstacle_" + str(obstacle.obstacle_type))
	
	if contents.is_empty():
		return "empty"
	else:
		return ", ".join(contents)

func check_and_clear_highlight_on_arrival(player_pos: Vector2i):
	"""Clear highlight if player has reached the highlighted tile"""
	if highlighted_tile:
		# Get the grid position of the highlighted tile
		var highlighted_pos = Vector2i(highlighted_tile.grid_x, highlighted_tile.grid_y)
		print("Player at (", player_pos.x, ", ", player_pos.y, "), highlighted tile at (", highlighted_pos.x, ", ", highlighted_pos.y, ")")
		
		# If player reached the highlighted tile, clear the highlight
		if player_pos == highlighted_pos:
			print("Player reached highlighted tile - clearing highlight")
			clear_highlight()

func show_combat_menu(enemy: CharacterBody2D):
	"""Show combat menu above the specified enemy"""
	# Close any existing menu
	hide_combat_menu()
	
	combat_target_enemy = enemy
	
	# Create combat menu UI as a popup to ensure proper event handling
	active_combat_menu = PopupPanel.new()
	active_combat_menu.name = "CombatMenu"
	active_combat_menu.set_flag(Window.FLAG_POPUP, true)
	
	# Position menu above enemy using enemy's global position
	var enemy_world_pos = enemy.global_position
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_pos = get_viewport().get_camera_2d().global_position
	var screen_center = get_viewport().get_camera_2d().get_screen_center_position()
	
	print("=== COMBAT MENU POSITIONING DEBUG ===")
	print("Enemy world pos: ", enemy_world_pos)
	print("Enemy grid pos: (", enemy.grid_x, ", ", enemy.grid_y, ")")
	print("Camera pos: ", camera_pos)
	print("Screen center: ", screen_center)
	print("Viewport size: ", viewport_size)
	
	# Try a simple approach: use the enemy's position directly
	# Since we're adding to root, let's try different coordinate approaches
	
	# Approach 1: Simple offset from enemy position
	var menu_pos_1 = enemy_world_pos + Vector2(-60, -80)
	
	# Approach 2: Convert using screen center offset
	var enemy_screen_pos = screen_center + (enemy_world_pos - camera_pos)
	var menu_pos_2 = enemy_screen_pos + Vector2(-60, -80)
	
	# Approach 3: Direct viewport coordinate conversion
	var canvas_transform = get_viewport().get_canvas_transform()
	var menu_pos_3 = canvas_transform * enemy_world_pos + Vector2(-60, -80)
	
	print("Menu position approach 1 (world + offset): ", menu_pos_1)
	print("Menu position approach 2 (screen center): ", menu_pos_2)
	print("Menu position approach 3 (canvas transform): ", menu_pos_3)
	
	# Choose approach 3 (canvas transform) and ensure it's within viewport bounds
	var final_menu_pos = menu_pos_3
	
	# Ensure menu stays within viewport bounds
	var menu_size = Vector2(120, 80)
	final_menu_pos.x = clamp(final_menu_pos.x, 0, viewport_size.x - menu_size.x)
	final_menu_pos.y = clamp(final_menu_pos.y, 0, viewport_size.y - menu_size.y)
	
	# If the menu would be off-screen above, put it below the enemy instead
	if menu_pos_3.y < 0:
		final_menu_pos = canvas_transform * enemy_world_pos + Vector2(-60, 20)  # Below enemy
		final_menu_pos.y = clamp(final_menu_pos.y, 0, viewport_size.y - menu_size.y)
	
	active_combat_menu.position = final_menu_pos
	active_combat_menu.size = menu_size
	
	print("FINAL menu position (clamped): ", active_combat_menu.position)
	
	# Create container for buttons
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	active_combat_menu.add_child(vbox)
	
	# Create attack button
	var attack_button = Button.new()
	attack_button.text = "Attack"
	attack_button.custom_minimum_size = Vector2(100, 30)
	attack_button.pressed.connect(_on_attack_button_pressed)
	vbox.add_child(attack_button)
	
	# Create steal button
	var steal_button = Button.new()
	steal_button.text = "Steal"
	steal_button.custom_minimum_size = Vector2(100, 30)
	steal_button.pressed.connect(_on_steal_button_pressed)
	vbox.add_child(steal_button)
	
	# Add to scene and show
	get_tree().root.add_child(active_combat_menu)
	active_combat_menu.popup()
	
	# Connect popup close to cleanup function
	active_combat_menu.popup_hide.connect(_on_combat_menu_popup_hide)
	
	print("Combat menu opened for enemy at (", enemy.grid_x, ", ", enemy.grid_y, ")")

func _on_combat_menu_popup_hide():
	"""Handle popup hide signal to cleanup combat menu"""
	combat_target_enemy = null
	active_combat_menu = null
	print("Combat menu auto-closed")

func hide_combat_menu():
	"""Hide and remove the combat menu"""
	if active_combat_menu and is_instance_valid(active_combat_menu):
		# Disconnect signal to prevent recursive calls
		if active_combat_menu.popup_hide.is_connected(_on_combat_menu_popup_hide):
			active_combat_menu.popup_hide.disconnect(_on_combat_menu_popup_hide)
		active_combat_menu.hide()
		active_combat_menu.queue_free()
		active_combat_menu = null
		combat_target_enemy = null
		print("Combat menu closed")

func _on_attack_button_pressed():
	"""Handle attack button press"""
	print("=== ATTACK BUTTON PRESSED ===")
	print("Combat target enemy: ", combat_target_enemy)
	print("Current battle state: ", is_in_battle)
	if combat_target_enemy:
		# Store the enemy reference before hiding menu
		var target_enemy = combat_target_enemy
		# Hide menu first to clean up UI
		hide_combat_menu()
		# Play attack animation with stored reference
		play_attack_animation(target_enemy)
	else:
		print("ERROR: No combat target enemy!")
		hide_combat_menu()

func _on_steal_button_pressed():
	"""Handle steal button press"""
	print("Steal button pressed!")
	if combat_target_enemy:
		# TODO: Implement steal mechanics
		print("Steal action not yet implemented")
		# Hide menu for now
		hide_combat_menu()

func play_attack_animation(target_enemy: CharacterBody2D):
	"""Play sword attack animation and enter battle mode"""
	print("=== PLAYING ATTACK ANIMATION ===")
	print("Target enemy: ", target_enemy)
	print("Target enemy position: (", target_enemy.grid_x, ", ", target_enemy.grid_y, ")")
	
	# Get positions
	var player_pos = get_world_position(Vector2i(player.grid_x, player.grid_y))
	var enemy_pos = get_world_position(Vector2i(target_enemy.grid_x, target_enemy.grid_y))
	
	# Calculate direction from player to enemy
	var direction = (enemy_pos - player_pos).normalized()
	print("Animation direction: ", direction)
	
	# Create simple sword effect (yellow line that flashes)
	var sword_line = Line2D.new()
	sword_line.add_point(player_pos)
	sword_line.add_point(player_pos + direction * 40)  # 40 pixel sword
	sword_line.width = 4
	sword_line.default_color = Color.YELLOW
	sword_line.z_index = 50
	add_child(sword_line)
	
	# Animate sword slash
	var slash_tween = create_tween()
	slash_tween.tween_property(sword_line, "default_color", Color.RED, 0.1)
	slash_tween.tween_property(sword_line, "default_color", Color.WHITE, 0.1)
	slash_tween.tween_callback(sword_line.queue_free)
	# Use a simpler callback approach
	slash_tween.finished.connect(func(): _on_attack_animation_complete(target_enemy))
	
	print("Sword animation started, tween created")

func _on_attack_animation_complete(target_enemy: CharacterBody2D):
	"""Called when attack animation finishes"""
	print("=== ANIMATION COMPLETE CALLBACK ===")
	print("Target enemy: ", target_enemy)
	print("About to enter battle mode")
	# Enter battle mode with this specific enemy
	enter_battle_mode([target_enemy])
	print("Battle mode entry completed")

func clear_highlight():
	"""Clear current tile highlight"""
	if highlighted_tile:
		highlighted_tile.set_highlighted(false)
		highlighted_tile = null

func update_battle_ui():
	"""Update UI to reflect current battle state"""
	var instructions_label = get_node_or_null("UI/InfoPanel/VBoxContainer/Instructions")
	if instructions_label:
		if is_in_battle:
			instructions_label.text = "BATTLE MODE
Turn-based combat active
Wait for battle resolution"
		else:
			instructions_label.text = "EXPLORATION MODE
Click tiles to move
Arrow keys for single steps
Right-click to stop movement"

func drop_loot_around_enemies():
	"""Drop loot items strategically across the entire field"""
	print("=== FILLING FIELD WITH LOOT (ORGANIZED) ===")
	print("Loot array size before dropping: ", loot_items.size())
	
	# First, collect all valid positions
	var valid_positions: Array[Vector2i] = []
	var enemy_positions: Array[Vector2i] = []
	
	for x in range(grid_size):
		for y in range(grid_size):
			var pos = Vector2i(x, y)
			var enemy_at_pos = get_enemy_at_position(pos)
			
			if enemy_at_pos:
				enemy_positions.append(pos)
			elif is_valid_loot_position(pos):
				valid_positions.append(pos)
	
	print("Found ", valid_positions.size(), " valid positions and ", enemy_positions.size(), " enemy positions")
	
	# Create organized loot distribution
	create_organized_loot_distribution(valid_positions, enemy_positions)
	
	print("Total loot items created: ", loot_items.size())

func create_organized_loot_distribution(valid_pos: Array[Vector2i], enemy_pos: Array[Vector2i]):
	"""Create a sophisticated strategic loot distribution system"""
	print("=== STRATEGIC LOOT DISTRIBUTION SYSTEM ===")
	
	# Step 1: Ensure connectivity and movement corridors
	var strategic_positions = ensure_movement_corridors(valid_pos)
	
	# Step 2: Create loot clusters for match-3 opportunities
	var loot_clusters = create_strategic_clusters(strategic_positions)
	
	# Step 3: Distribute loot types strategically
	distribute_loot_strategically(loot_clusters, enemy_pos)
	
	print("Strategic distribution complete: ", loot_items.size(), " items placed")

func ensure_movement_corridors(valid_pos: Array[Vector2i]) -> Array[Vector2i]:
	"""Ensure player always has movement options by reserving corridors"""
	var strategic_positions = valid_pos.duplicate()
	var player_pos = Vector2i(player.grid_x, player.grid_y)
	
	# Reserve corridors around player (3x3 area)
	var reserved_positions: Array[Vector2i] = []
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			var check_pos = player_pos + Vector2i(x_offset, y_offset)
			if check_pos in strategic_positions:
				reserved_positions.append(check_pos)
	
	# Remove some positions around player to ensure movement
	for pos in reserved_positions:
		if randf() < 0.4:  # 40% chance to keep empty for movement
			strategic_positions.erase(pos)
	
	# Reserve main pathways (every 3rd row/column as corridors)
	for i in range(strategic_positions.size() - 1, -1, -1):
		var pos = strategic_positions[i]
		if (pos.x % 3 == 1) or (pos.y % 3 == 1):  # Corridor positions
			if randf() < 0.3:  # 30% chance to keep as corridor
				strategic_positions.remove_at(i)
	
	print("Reserved corridors, usable positions: ", strategic_positions.size())
	return strategic_positions

func create_strategic_clusters(positions: Array[Vector2i]) -> Dictionary:
	"""Create clusters of positions for strategic loot placement"""
	var clusters = {
		"high_value": [],    # Near enemies, harder to reach
		"medium_value": [],  # Moderate accessibility
		"easy_access": [],   # Close to player, easy to collect
		"chain_starters": [] # Positions that can start good chains
	}
	
	var player_pos = Vector2i(player.grid_x, player.grid_y)
	
	for pos in positions:
		var distance_to_player = abs(pos.x - player_pos.x) + abs(pos.y - player_pos.y)
		var near_enemy = false
		
		# Check if near any enemy
		for enemy in enemies:
			var enemy_distance = abs(pos.x - enemy.grid_x) + abs(pos.y - enemy.grid_y)
			if enemy_distance <= 2:
				near_enemy = true
				break
		
		# Classify position based on strategic value
		if near_enemy and distance_to_player > 4:
			clusters["high_value"].append(pos)
		elif distance_to_player <= 2:
			clusters["easy_access"].append(pos)
		elif has_cluster_potential(pos, positions):
			clusters["chain_starters"].append(pos)
		else:
			clusters["medium_value"].append(pos)
	
	print("Clusters created - High:", clusters["high_value"].size(), 
		  " Medium:", clusters["medium_value"].size(),
		  " Easy:", clusters["easy_access"].size(),
		  " Chains:", clusters["chain_starters"].size())
	
	return clusters

func has_cluster_potential(pos: Vector2i, all_positions: Array[Vector2i]) -> bool:
	"""Check if position has potential for creating good match-3 clusters"""
	var adjacent_count = 0
	var directions = [Vector2i(0,1), Vector2i(1,0), Vector2i(0,-1), Vector2i(-1,0)]
	
	for direction in directions:
		var check_pos = pos + direction
		if check_pos in all_positions:
			adjacent_count += 1
	
	return adjacent_count >= 2  # Good for clusters if 2+ adjacent positions

func distribute_loot_strategically(clusters: Dictionary, enemy_positions: Array[Vector2i]):
	"""Distribute loot types based on strategic considerations"""
	var loot_types = get_all_loot_types()
	
	# Strategic distribution rules
	place_high_value_loot(clusters["high_value"])           # Weapons/rare items near enemies
	place_chain_starter_loot(clusters["chain_starters"])    # Same types for good chains  
	place_easy_access_loot(clusters["easy_access"])         # Currency/common items
	place_medium_value_loot(clusters["medium_value"])       # Balanced mix
	create_enemy_loot_items(enemy_positions)                # Enemy loot items

func place_high_value_loot(positions: Array[Vector2i]):
	"""Place valuable loot (weapons, armor) in high-risk positions"""
	var valuable_types = ["sword", "shield"]
	for pos in positions:
		if positions.size() > 0:
			var loot_type = valuable_types[randi() % valuable_types.size()]
			create_loot_item_at_position(loot_type, pos)

func place_chain_starter_loot(positions: Array[Vector2i]):
	"""Place same-type loot in clusters to enable good chains"""
	if positions.size() == 0:
		return
	
	var cluster_type = ["coin", "health_potion"][randi() % 2]  # Choose one type for cluster
	for i in range(min(positions.size(), 6)):  # Limit cluster size
		create_loot_item_at_position(cluster_type, positions[i])

func place_easy_access_loot(positions: Array[Vector2i]):
	"""Place common loot near player for easy early collection"""
	for pos in positions:
		var common_type = "coin"  # Most common, easy to collect
		create_loot_item_at_position(common_type, pos)

func place_medium_value_loot(positions: Array[Vector2i]):
	"""Place balanced mix of loot types"""
	var balanced_types = ["coin", "health_potion", "sword", "shield"]
	for pos in positions:
		var loot_type = balanced_types[randi() % balanced_types.size()]
		create_loot_item_at_position(loot_type, pos)

func create_enemy_loot_items(enemy_positions: Array[Vector2i]):
	"""Create enemy loot items at enemy positions"""
	for pos in enemy_positions:
		var enemy_at_pos = null
		for enemy in enemies:
			if Vector2i(enemy.grid_x, enemy.grid_y) == pos:
				enemy_at_pos = enemy
				break
		
		if enemy_at_pos:
			create_enemy_loot_item(pos, enemy_at_pos)

func create_loot_item_at_position(loot_type: String, pos: Vector2i):
	"""Helper function to create individual loot items"""
	var loot_item = preload("res://LootItem.gd").new()
	loot_item.setup(loot_type, pos)
	
	# Position in world coordinates
	var world_pos = get_world_position(pos)
	loot_item.position = world_pos
	
	# Connect collection signal
	loot_item.item_collected.connect(_on_loot_item_collected)
	
	# Add to scene and tracking array
	add_child(loot_item)
	loot_items.append(loot_item)
		var items_in_category = loot_categories[category]
		for i in range(quantity):
			var random_item = items_in_category[randi() % items_in_category.size()]
			loot_plan.append(random_item)
	
	# Fill remaining slots with random items if needed
	while loot_plan.size() < total_positions:
		var all_types = get_all_loot_types()
		var random_type = all_types[randi() % all_types.size()]
		if random_type not in loot_categories["enemies"]:  # Don't add enemy loot randomly
			loot_plan.append(random_type)
	
	# Shuffle the plan for random placement
	loot_plan.shuffle()
	
	print("=== PLACING LOOT ITEMS ===")
	
	# Place enemy loot items first
	for pos in enemy_pos:
		var enemy_at_pos = get_enemy_at_position(pos)
		create_enemy_loot_item(pos, enemy_at_pos)
	
	# Place regular loot items according to plan
	for i in range(min(loot_plan.size(), valid_pos.size())):
		var pos = valid_pos[i]
		var loot_type = loot_plan[i]
		create_specific_loot_item(pos, loot_type)
	
	print("=== LOOT DISTRIBUTION COMPLETE ===")

func is_valid_loot_position(pos: Vector2i) -> bool:
	"""Check if a position is valid for dropping loot"""
	# Check bounds
	if pos.x < 0 or pos.x >= grid_size or pos.y < 0 or pos.y >= grid_size:
		return false
	
	# Check for obstacles
	var obstacle = get_obstacle(pos.x, pos.y)
	if obstacle:
		return false
	
	# Check if position is occupied by player or enemy
	if player and player.grid_x == pos.x and player.grid_y == pos.y:
		return false
	
	for enemy in enemies:
		if enemy.grid_x == pos.x and enemy.grid_y == pos.y:
			return false
	
	# Check if there's already loot at this position
	for loot in loot_items:
		if loot.grid_x == pos.x and loot.grid_y == pos.y:
			return false
	
	return true

func get_enemy_at_position(pos: Vector2i) -> CharacterBody2D:
	"""Get enemy at specific position, return null if none"""
	for enemy in enemies:
		if enemy.grid_x == pos.x and enemy.grid_y == pos.y:
			return enemy
	return null

func create_enemy_loot_item(pos: Vector2i, enemy: CharacterBody2D):
	"""Create an enemy loot item at the specified position"""
	# Determine enemy type based on enemy name or create random enemy type
	var enemy_types = loot_categories["enemies"]
	var enemy_loot_type = enemy_types[randi() % enemy_types.size()]
	
	print("Creating enemy loot: ", enemy_loot_type, " at (", pos.x, ", ", pos.y, ") for enemy: ", enemy.name)
	
	# Create LootItem instance for the enemy
	var loot_item = preload("res://LootItem.gd").new()
	loot_item.setup(enemy_loot_type, pos)
	
	# Position in world coordinates (same as enemy)
	var world_pos = get_world_position(pos)
	loot_item.position = world_pos
	
	# Connect collection signal
	loot_item.item_collected.connect(_on_loot_item_collected)
	
	# Store reference to original enemy in the loot item
	loot_item.original_enemy = enemy
	
	# Add to scene and tracking array
	add_child(loot_item)
	loot_items.append(loot_item)
	
	# Hide the original enemy (we'll handle it through loot system now)
	enemy.visible = false
	
	print("Enemy loot ", enemy_loot_type, " created at (", pos.x, ", ", pos.y, ") - Array size now: ", loot_items.size())

func remove_enemy_at_position(pos: Vector2i):
	"""Remove enemy at specific position from the game"""
	for i in range(enemies.size() - 1, -1, -1):  # Iterate backwards to avoid index issues
		var enemy = enemies[i]
		if enemy.grid_x == pos.x and enemy.grid_y == pos.y:
			print("Removing enemy at position (", pos.x, ", ", pos.y, ")")
			enemies.erase(enemy)
			enemy.queue_free()
			break

func create_specific_loot_item(pos: Vector2i, loot_type: String):
	"""Create a specific loot item at the specified grid position"""
	# Create LootItem instance
	var loot_item = preload("res://LootItem.gd").new()
	loot_item.setup(loot_type, pos)
	
	# Position in world coordinates
	var world_pos = get_world_position(pos)
	loot_item.position = world_pos
	
	# Connect collection signal
	loot_item.item_collected.connect(_on_loot_item_collected)
	
	# Add to scene and tracking array
	add_child(loot_item)
	loot_items.append(loot_item)
	
	print("Placed ", loot_type, " at (", pos.x, ", ", pos.y, ")")

func create_loot_item(pos: Vector2i):
	"""Create a random loot item at the specified grid position (legacy function)"""
	var all_types = get_all_loot_types()
	var loot_type = all_types[randi() % all_types.size()]
	
	# Use the specific creation function
	create_specific_loot_item(pos, loot_type)
