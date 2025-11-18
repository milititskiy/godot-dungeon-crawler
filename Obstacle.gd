class_name Obstacle
extends Node2D

enum ObstacleType {
	WALL,        # Blocks movement completely
	INTERACTIVE, # Can be interacted with (doors, chests, etc.)
	DESTRUCTIBLE,# Can be destroyed
	TRAP         # Damages entities
}

@export var obstacle_type: ObstacleType = ObstacleType.WALL
@export var grid_x: int = 0
@export var grid_y: int = 0
@export var is_passable: bool = false
@export var requires_interaction: bool = false
@export var health: int = 1
@export var damage: int = 0

var game_field: Node2D
var sprite: Sprite2D
var collision_shape: CollisionShape2D

signal obstacle_interacted(obstacle: Obstacle, interactor: CharacterBody2D)
signal obstacle_destroyed(obstacle: Obstacle)
signal obstacle_triggered(obstacle: Obstacle, trigger: CharacterBody2D)

func _ready():
	game_field = get_parent().get_parent() # Assuming obstacles are children of grid_container
	setup_visuals()
	setup_collision()

func setup_visuals():
	# Create visual representation based on type
	var color_rect = ColorRect.new()
	add_child(color_rect)
	
	# Set size and position
	color_rect.size = Vector2(60, 60)  # Slightly smaller than tile
	color_rect.position = Vector2(-30, -30)  # Center it
	
	# Set color based on type
	match obstacle_type:
		ObstacleType.WALL:
			color_rect.color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray
		ObstacleType.INTERACTIVE:
			color_rect.color = Color(0.6, 0.4, 0.8, 1.0)  # Purple
		ObstacleType.DESTRUCTIBLE:
			color_rect.color = Color(0.8, 0.6, 0.4, 1.0)  # Brown
		ObstacleType.TRAP:
			color_rect.color = Color(0.8, 0.2, 0.2, 1.0)  # Red
	
	# Add border
	var border = ColorRect.new()
	add_child(border)
	border.size = Vector2(64, 64)
	border.position = Vector2(-32, -32)
	border.color = Color(0.1, 0.1, 0.1, 1.0)
	border.z_index = -1

func setup_collision():
	# Create collision for interactive obstacles
	if obstacle_type == ObstacleType.INTERACTIVE:
		var area = Area2D.new()
		add_child(area)
		
		var shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(60, 60)
		shape.shape = rect_shape
		area.add_child(shape)
		
		area.input_event.connect(_on_area_input_event)

func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		interact()

func interact(interactor: CharacterBody2D = null):
	print("Interacting with ", ObstacleType.keys()[obstacle_type], " obstacle at (", grid_x, ", ", grid_y, ")")
	
	match obstacle_type:
		ObstacleType.INTERACTIVE:
			handle_interactive(interactor)
		ObstacleType.DESTRUCTIBLE:
			take_damage(1)
		ObstacleType.TRAP:
			trigger_trap(interactor)

func handle_interactive(interactor: CharacterBody2D):
	# Toggle passability for doors, switches, etc.
	is_passable = !is_passable
	update_visual_state()
	obstacle_interacted.emit(self, interactor)
	print("Interactive obstacle toggled - passable: ", is_passable)

func take_damage(amount: int):
	health -= amount
	print("Obstacle took ", amount, " damage. Health: ", health)
	
	if health <= 0:
		destroy()
	else:
		# Visual damage effect (flash red)
		var tween = create_tween()
		modulate = Color.RED
		tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func destroy():
	print("Obstacle destroyed at (", grid_x, ", ", grid_y, ")")
	obstacle_destroyed.emit(self)
	
	# Remove from game field obstacle tracking
	if game_field and game_field.has_method("remove_obstacle"):
		game_field.remove_obstacle(self)
	
	queue_free()

func collect(collector: CharacterBody2D):
	var collector_name = "unknown"
	if collector:
		collector_name = collector.name
	print("Collectible picked up by ", collector_name)
	# Add to inventory, give points, etc.
	destroy()

func trigger_trap(victim: CharacterBody2D):
	var victim_name = "unknown"
	if victim:
		victim_name = str(victim.name)
	print("Trap triggered! Dealing ", damage, " damage to ", victim_name)
	obstacle_triggered.emit(self, victim)
	# Deal damage, apply effects, etc.

func update_visual_state():
	# Update visuals based on current state
	var color_rect = get_child(0) as ColorRect
	if color_rect:
		if obstacle_type == ObstacleType.INTERACTIVE:
			# Change color based on passable state
			color_rect.color = Color(0.6, 0.4, 0.8, 1.0) if not is_passable else Color(0.4, 0.8, 0.6, 1.0)

func set_grid_position(x: int, y: int):
	grid_x = x
	grid_y = y

func can_pass() -> bool:
	return is_passable

func blocks_movement() -> bool:
	return not can_pass()

func get_obstacle_data() -> Dictionary:
	return {
		"type": obstacle_type,
		"position": Vector2i(grid_x, grid_y),
		"passable": is_passable,
		"health": health,
		"damage": damage
	}