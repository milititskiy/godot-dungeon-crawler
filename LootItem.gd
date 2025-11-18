extends Node2D
class_name LootItem

signal item_collected(loot_item: LootItem)

@export var loot_type: String = ""
@export var grid_x: int = 0
@export var grid_y: int = 0

var original_enemy: CharacterBody2D = null  # Reference to original enemy (for enemy loot items)
var sprite: Node2D  # Can hold either Sprite2D or ColorRect
var area: Area2D
var collision_shape: CollisionShape2D

# Sprite paths for loot items
var loot_sprites = {
	"sword": "res://assets/sprites/items/sword.png",
	"shield": "res://assets/sprites/items/shield.png",
	"coin": "res://assets/sprites/items/coin.png",
	"health_potion": "res://assets/sprites/items/health_potion.png",
	"mana_potion": "res://assets/sprites/items/mana_potion.png",
	# Enemy loot types (all use the same enemy sprite)
	"goblin": "res://assets/sprites/enemies/enemy.png",
	"orc": "res://assets/sprites/enemies/enemy.png",
	"skeleton": "res://assets/sprites/enemies/enemy.png",
	"spider": "res://assets/sprites/enemies/enemy.png"
}

# Fallback colors if sprites aren't available
var loot_colors = {
	"sword": Color.SILVER,
	"shield": Color.BROWN,
	"coin": Color.YELLOW,
	"health_potion": Color.RED,
	"mana_potion": Color.BLUE
}

func _ready():
	# Try to create sprite representation first
	var sprite_path = loot_sprites.get(loot_type, "")
	
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		# Load texture and convert to remove alpha channel
		var original_texture = load(sprite_path) as CompressedTexture2D
		var image = original_texture.get_image()
		
		# Convert to RGB format (removes alpha channel)
		if image.get_format() == Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGB8)
		
		# Create new texture from the converted image
		var new_texture = ImageTexture.new()
		new_texture.set_image(image)
		
		var sprite_node = Sprite2D.new()
		sprite_node.texture = new_texture
		
		# Scale sprite to fit tile
		var sprite_size = new_texture.get_size()
		var target_size = 48.0
		var scale_factor = target_size / max(sprite_size.x, sprite_size.y)
		sprite_node.scale = Vector2(scale_factor, scale_factor)
		
		add_child(sprite_node)
		
		add_child(sprite_node)
		sprite = sprite_node
		print("Loaded sprite for ", loot_type, " at scale: ", scale_factor)
	else:
		# Fallback to colored rectangle if sprite not available
		print("Sprite not found for ", loot_type, ", using fallback")
		var background = ColorRect.new()
		background.size = Vector2(64, 64)  # Full tile size
		background.position = Vector2(-32, -32)  # Center on position
		background.color = loot_colors.get(loot_type, Color.WHITE)
		add_child(background)
		
		# Create text label for fallback
		var label = Label.new()
		label.text = loot_type.replace("_", " ").capitalize()
		label.size = Vector2(64, 64)
		label.position = Vector2(-32, -32)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_font_size_override("font_size", 10)
		add_child(label)
		
		sprite = background
	
	# Create interaction area (full cell size)
	area = Area2D.new()
	add_child(area)
	
	collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(64, 64)  # Full tile size
	collision_shape.shape = shape
	area.add_child(collision_shape)
	
	# Connect interaction signals
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		collect_item()

func _on_mouse_entered():
	# Visual feedback when hovering
	sprite.modulate = Color(1.2, 1.2, 1.2)  # Slightly brighter

func _on_mouse_exited():
	# Reset visual feedback
	sprite.modulate = Color.WHITE

func set_chain_highlight(enabled: bool):
	"""Set green border highlight for chain selection"""
	print("Setting highlight on ", loot_type, " at (", grid_x, ", ", grid_y, ") to: ", enabled)
	if enabled:
		# Add green border effect
		sprite.modulate = Color(0.6, 1.4, 0.6)  # Stronger green tint
		# TODO: Add actual border/outline shader or border sprite
	else:
		# Remove highlight
		sprite.modulate = Color.WHITE

func collect_item():
	"""Called when player clicks/interacts with the loot item"""
	print("Collected ", loot_type, " at (", grid_x, ", ", grid_y, ")")
	item_collected.emit(self)
	queue_free()

func setup(type: String, grid_position: Vector2i):
	"""Initialize the loot item with type and position"""
	loot_type = type
	grid_x = grid_position.x
	grid_y = grid_position.y
	name = "Loot_" + type + "_" + str(grid_x) + "_" + str(grid_y)
