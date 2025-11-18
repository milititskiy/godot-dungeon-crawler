extends CharacterBody2D

var grid_x: int = 0
var grid_y: int = 0
var game_field: Node2D
var tile_size: int = 64
var tile_spacing: int = 2
var player_ref: CharacterBody2D

# Movement and pathfinding
var move_timer: float = 0.0
var move_interval: float = 1.5  # Move every 1.5 seconds
var current_path: Array[Vector2i] = []
var path_index: int = 0
var is_moving: bool = false
var move_tween: Tween
var chase_range: int = 6  # Start chasing if player is within this range
var is_active: bool = false  # Controls whether enemy moves

func _ready():
	# Find the game field reference
	game_field = get_parent()
	
	# Setup enemy sprite
	setup_enemy_sprite()
	
	# Randomize move interval slightly for each enemy
	move_interval += randf_range(-0.3, 0.3)

func _physics_process(delta):
	move_timer += delta
	if move_timer >= move_interval:
		move_timer = 0.0
		ai_move()

func ai_move():
	if not player_ref or is_moving or not is_active:
		return
		
	# Don't move if we're in battle mode
	if game_field.is_in_battle:
		return
	
	# Calculate distance to player
	var distance_to_player = abs(player_ref.grid_x - grid_x) + abs(player_ref.grid_y - grid_y)
	
	# Decide behavior based on distance and probability
	var should_chase = distance_to_player <= chase_range and randf() < 0.7  # 70% chance to chase if in range
	
	if should_chase:
		# Use pathfinding to chase player
		chase_player()
	else:
		# Random movement
		random_move()

func chase_player():
	var player_pos = Vector2i(player_ref.grid_x, player_ref.grid_y)
	var enemy_pos = Vector2i(grid_x, grid_y)
	
	# Find path to player
	current_path = game_field.find_path_for_character(enemy_pos, player_pos, self)
	
	if current_path.size() > 0:
		# Move one step towards player (don't move all the way)
		var next_step = current_path[0]
		move_to_grid_pathfind(next_step.x, next_step.y)
		print("Enemy chasing player: moving to (", next_step.x, ", ", next_step.y, ")")
	else:
		# No path to player, try random movement
		random_move()

func random_move():
	# Try random directions until we find a walkable one
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	# Shuffle directions for randomness
	directions.shuffle()
	
	for dir in directions:
		var target_x = grid_x + dir.x
		var target_y = grid_y + dir.y
		
		if game_field.is_walkable_for_character(target_x, target_y, self):
			move_to_grid_pathfind(target_x, target_y)
			print("Enemy random move to (", target_x, ", ", target_y, ")")
			return
	
	print("Enemy cannot move - all directions blocked")

func move_to_grid_pathfind(new_x: int, new_y: int):
	# Check if player is at target position (attack!)
	if player_ref and player_ref.grid_x == new_x and player_ref.grid_y == new_y:
		print("Enemy attacked player at (", new_x, ", ", new_y, ")!")
		# Could add damage system here
		return
	
	# Validate move (should be pre-validated by pathfinding, but double-check)
	if not game_field.is_walkable_for_character(new_x, new_y, self):
		return
	
	# Start movement
	is_moving = true
	grid_x = new_x
	grid_y = new_y
	
	# Update world position
	var new_pos = game_field.get_world_position(Vector2i(grid_x, grid_y))
	
	# Stop previous tween if exists
	if move_tween:
		move_tween.kill()
	
	# Smooth movement
	move_tween = create_tween()
	move_tween.tween_property(self, "position", new_pos, 0.3)
	move_tween.tween_callback(_on_move_completed)

func _on_move_completed():
	is_moving = false

func set_grid_position(x: int, y: int):
	grid_x = x
	grid_y = y
	
	# Set initial world position
	var world_pos = game_field.get_world_position(Vector2i(grid_x, grid_y))
	position = world_pos

func get_grid_position() -> Vector2i:
	return Vector2i(grid_x, grid_y)

func set_player_reference(player: CharacterBody2D):
	player_ref = player

func set_active(active: bool):
	is_active = active
	if not active:
		# Stop any current movement when deactivated
		if move_tween:
			move_tween.kill()
		is_moving = false

func stop_movement():
	"""Stop current movement immediately"""
	print("Enemy stopping movement")
	if move_tween:
		move_tween.kill()
		move_tween = null
	is_moving = false

func resume_movement():
	"""Resume normal movement (used when exiting battle)"""
	print("Enemy resuming movement")
	# Movement will resume on next ai_move() cycle if active

func setup_enemy_sprite():
	"""Setup enemy visual representation using enemy sprite"""
	var enemy_sprite_path = "res://assets/sprites/enemies/enemy.png"
	
	if ResourceLoader.exists(enemy_sprite_path):
		# Load and use enemy sprite
		var sprite_node = Sprite2D.new()
		var texture = load(enemy_sprite_path)
		sprite_node.texture = texture
		
		# Scale sprite to fit enemy size (adjust as needed)
		var sprite_size = texture.get_size()
		var target_size = 48.0  # Slightly smaller than tile for padding
		var scale_factor = target_size / max(sprite_size.x, sprite_size.y)
		sprite_node.scale = Vector2(scale_factor, scale_factor)
		
		add_child(sprite_node)
		print("Loaded enemy sprite at scale: ", scale_factor)
	else:
		# Fallback to colored rectangle if sprite not available
		print("Enemy sprite not found, using fallback")
		var background = ColorRect.new()
		background.size = Vector2(48, 48)
		background.position = Vector2(-24, -24)
		background.color = Color.PURPLE
		add_child(background)