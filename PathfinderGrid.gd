class_name PathfinderGrid
extends RefCounted

# A* pathfinding implementation for grid-based movement

class PathNode:
	var position: Vector2i
	var g_cost: float = 0.0  # Distance from start
	var h_cost: float = 0.0  # Distance to end (heuristic)
	var f_cost: float = 0.0  # Total cost (g + h)
	var parent: PathNode = null
	
	func _init(pos: Vector2i):
		position = pos
	
	func calculate_f_cost():
		f_cost = g_cost + h_cost

static func find_path(start: Vector2i, end: Vector2i, grid_size: Vector2i, is_walkable: Callable) -> Array[Vector2i]:
	var open_list: Array[PathNode] = []
	var closed_list: Array[PathNode] = []
	var all_nodes: Dictionary = {}
	
	# Create start node
	var start_node = PathNode.new(start)
	start_node.g_cost = 0
	start_node.h_cost = _calculate_distance(start, end)
	start_node.calculate_f_cost()
	
	open_list.append(start_node)
	all_nodes[_vector_to_key(start)] = start_node
	
	while open_list.size() > 0:
		# Find node with lowest f_cost
		var current_node = _get_lowest_f_cost_node(open_list)
		
		# Remove from open list and add to closed list
		open_list.erase(current_node)
		closed_list.append(current_node)
		
		# Check if we reached the end
		if current_node.position == end:
			return _retrace_path(start_node, current_node)
		
		# Check all neighbors
		var neighbors = _get_neighbors(current_node.position, grid_size)
		for neighbor_pos in neighbors:
			# Skip if not walkable or already in closed list
			if not is_walkable.call(neighbor_pos.x, neighbor_pos.y):
				continue
			
			if _is_in_closed_list(neighbor_pos, closed_list):
				continue
			
			# Create neighbor node if it doesn't exist
			var neighbor_key = _vector_to_key(neighbor_pos)
			var neighbor_node: PathNode
			
			if neighbor_key in all_nodes:
				neighbor_node = all_nodes[neighbor_key]
			else:
				neighbor_node = PathNode.new(neighbor_pos)
				all_nodes[neighbor_key] = neighbor_node
			
			# Calculate costs
			var new_g_cost = current_node.g_cost + _calculate_distance(current_node.position, neighbor_pos)
			
			# If this path to neighbor is better than previous one
			if new_g_cost < neighbor_node.g_cost or not _is_in_open_list(neighbor_node, open_list):
				neighbor_node.g_cost = new_g_cost
				neighbor_node.h_cost = _calculate_distance(neighbor_pos, end)
				neighbor_node.calculate_f_cost()
				neighbor_node.parent = current_node
				
				if not _is_in_open_list(neighbor_node, open_list):
					open_list.append(neighbor_node)
	
	# No path found
	return []

static func _calculate_distance(a: Vector2i, b: Vector2i) -> float:
	# Manhattan distance for grid-based movement
	return abs(a.x - b.x) + abs(a.y - b.y)

static func _get_neighbors(pos: Vector2i, grid_size: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(0, 1),   # Down
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0)   # Left
	]
	
	for dir in directions:
		var neighbor = pos + dir
		if neighbor.x >= 0 and neighbor.x < grid_size.x and neighbor.y >= 0 and neighbor.y < grid_size.y:
			neighbors.append(neighbor)
	
	return neighbors

static func _get_lowest_f_cost_node(open_list: Array[PathNode]) -> PathNode:
	var lowest_node = open_list[0]
	for node in open_list:
		if node.f_cost < lowest_node.f_cost or (node.f_cost == lowest_node.f_cost and node.h_cost < lowest_node.h_cost):
			lowest_node = node
	return lowest_node

static func _is_in_closed_list(pos: Vector2i, closed_list: Array[PathNode]) -> bool:
	for node in closed_list:
		if node.position == pos:
			return true
	return false

static func _is_in_open_list(target_node: PathNode, open_list: Array[PathNode]) -> bool:
	return target_node in open_list

static func _retrace_path(start_node: PathNode, end_node: PathNode) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current_node = end_node
	
	while current_node != start_node:
		path.append(current_node.position)
		current_node = current_node.parent
	
	path.reverse()
	return path

static func _vector_to_key(pos: Vector2i) -> String:
	return str(pos.x) + "," + str(pos.y)