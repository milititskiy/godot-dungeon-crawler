extends Area2D

@export var grid_x: int = 0
@export var grid_y: int = 0
@export var tile_type: String = "empty"

var is_occupied: bool = false
var is_highlighted: bool = false
var hover_color = Color(0.8, 0.8, 1.0, 1)
var normal_color = Color(0.5, 0.5, 0.5, 1)
var occupied_color = Color(0.8, 0.4, 0.4, 1)
var highlight_color = Color(1.0, 1.0, 0.0, 1)  # Yellow highlight

@onready var color_rect = $ColorRect
@onready var highlight_border: Control

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	# Create highlight border
	create_highlight_border()
	update_appearance()

func _on_mouse_entered():
	if not is_occupied:
		color_rect.color = hover_color

func _on_mouse_exited():
	update_appearance()

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			toggle_occupation()

func toggle_occupation():
	is_occupied = !is_occupied
	update_appearance()
	print("Tile (", grid_x, ", ", grid_y, ") occupied: ", is_occupied)

func create_highlight_border():
	"""Create a yellow frame border for highlighting"""
	print("Creating highlight frame for tile (", grid_x, ", ", grid_y, ")")
	
	# Create container for the frame
	highlight_border = Control.new()
	highlight_border.name = "HighlightFrame"
	highlight_border.size = color_rect.size
	highlight_border.position = color_rect.position
	highlight_border.visible = false
	highlight_border.z_index = 5
	
	# Create 4 frame edges
	var frame_thickness = 3  # 3 pixel thick frame
	var frame_color = Color(1.0, 1.0, 0.0, 1.0)  # Solid bright yellow
	
	# Top edge
	var top_edge = ColorRect.new()
	top_edge.color = frame_color
	top_edge.size = Vector2(color_rect.size.x, frame_thickness)
	top_edge.position = Vector2(0, 0)
	highlight_border.add_child(top_edge)
	
	# Bottom edge  
	var bottom_edge = ColorRect.new()
	bottom_edge.color = frame_color
	bottom_edge.size = Vector2(color_rect.size.x, frame_thickness)
	bottom_edge.position = Vector2(0, color_rect.size.y - frame_thickness)
	highlight_border.add_child(bottom_edge)
	
	# Left edge
	var left_edge = ColorRect.new()
	left_edge.color = frame_color
	left_edge.size = Vector2(frame_thickness, color_rect.size.y)
	left_edge.position = Vector2(0, 0)
	highlight_border.add_child(left_edge)
	
	# Right edge
	var right_edge = ColorRect.new()
	right_edge.color = frame_color
	right_edge.size = Vector2(frame_thickness, color_rect.size.y)
	right_edge.position = Vector2(color_rect.size.x - frame_thickness, 0)
	highlight_border.add_child(right_edge)
	
	# Add to this tile as a child
	add_child(highlight_border)
	print("Highlight frame created with 4 edges")

func set_highlighted(highlighted: bool):
	"""Set the highlight state of this tile"""
	print("=== SET_HIGHLIGHTED CALLED ===")
	print("Tile (", grid_x, ", ", grid_y, ") setting highlighted to: ", highlighted)
	print("highlight_border exists: ", highlight_border != null)
	print("Tile position: ", position, " size: ", color_rect.size if color_rect else "no color_rect")
	
	is_highlighted = highlighted
	if highlight_border:
		highlight_border.visible = highlighted
		print("Highlight border visibility set to: ", highlighted)
		print("Highlight border position: ", highlight_border.position, " size: ", highlight_border.size)
	else:
		print("ERROR: highlight_border is null!")
	print("Final highlighted state: ", is_highlighted)

func update_appearance():
	if is_occupied:
		color_rect.color = occupied_color
	else:
		color_rect.color = normal_color

func set_grid_position(x: int, y: int):
	grid_x = x
	grid_y = y