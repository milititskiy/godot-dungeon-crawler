extends Resource
class_name LootGenerationConfig

## 🎯 STRATEGIC LOOT GENERATION CONFIGURATION
## This file controls all aspects of the sophisticated loot placement system

# ================================
# 🏗️ FIELD COVERAGE SETTINGS
# ================================

## Overall loot density (0.0 = no loot, 1.0 = every valid position has loot)
@export var field_coverage_ratio: float = 0.75

## Minimum loot items guaranteed on field (safety net for small grids)
@export var minimum_loot_items: int = 15

## Maximum loot items (prevents overcrowding on large grids)
@export var maximum_loot_items: int = 60

# ================================
# 🛡️ MOVEMENT CORRIDOR SYSTEM
# ================================

## How aggressive corridor reservation is (higher = more empty corridors)
@export var corridor_reservation_frequency: int = 4  # Every Nth row/column
@export var corridor_reservation_chance: float = 0.2  # 20% chance to reserve

## Player area protection (clear space around player)
@export var player_clear_radius: int = 0  # 0 = only player position, 1 = 3x3 area, etc.
@export var player_area_clear_chance: float = 0.4  # Chance to clear each position

# ================================
# 🎯 STRATEGIC CLUSTER DISTRIBUTION
# ================================

## Distribution of loot into strategic categories (should sum to ~1.0)
@export var strategic_distribution_ratios = {
	"high_value": 0.15,     # 15% - Weapons/armor near enemies (risky)
	"chain_starters": 0.25, # 25% - Same-type clusters for match-3 chains
	"easy_access": 0.20,    # 20% - Common items near player (safe)
	"medium_value": 0.40    # 40% - Balanced mix (general gameplay)
}

## Distance thresholds for categorization
@export var high_value_enemy_distance: int = 2     # Max distance to enemy for high-value
@export var high_value_player_distance: int = 4    # Min distance from player for high-value
@export var easy_access_player_distance: int = 2   # Max distance from player for easy access

## Chain starter cluster settings
@export var max_chain_cluster_size: int = 6        # Max items per cluster
@export var chain_cluster_spacing: int = 3         # Min distance between clusters

# ================================
# 🏆 LOOT TYPE PROBABILITIES
# ================================

## High-value loot types (placed near enemies)
var high_value_types = ["sword", "shield"]
var high_value_weights = [0.6, 0.4]  # Sword more common than shield

## Chain starter loot types (for guaranteed clusters)
var chain_starter_types = ["coin", "health_potion"]
var chain_starter_weights = [0.7, 0.3]  # Coins more common

## Balanced mix for medium-value positions
var balanced_types = ["coin", "health_potion", "sword", "shield"]  
var balanced_weights = [0.4, 0.3, 0.2, 0.1]  # Coins most common, shields rarest

## Filler types for remaining positions
var filler_types = ["coin", "health_potion", "sword", "shield"]
var filler_weights = [0.5, 0.25, 0.15, 0.1]  # Heavy coin bias for filler

# ================================
# 🤖 ENEMY LOOT GENERATION
# ================================

## Enemy loot types and their rarities
var enemy_loot_types = ["goblin", "orc", "skeleton", "spider"]
var enemy_loot_weights = [0.3, 0.25, 0.25, 0.2]  # Goblins most common

## Always create enemy loot items?
@export var always_create_enemy_loot: bool = true

# ================================
# 🆘 ANTI-DEADLOCK PARAMETERS  
# ================================

## How often to check for deadlock situations (seconds)
@export var deadlock_check_interval: float = 5.0

## How long player can be stuck before intervention (seconds)  
@export var max_stuck_time: float = 10.0

## Minimum movement options before triggering deadlock resolution
@export var min_movement_options: int = 2

## Minimum total actions (move + combat + loot) before intervention
@export var min_total_actions: int = 1

# ================================
# 🔧 EMERGENCY RESOLUTION SETTINGS
# ================================

## Emergency loot type for deadlock resolution
@export var emergency_loot_type: String = "coin"

## How many emergency loot items to place
@export var emergency_loot_count: int = 2

## Distance from player for emergency loot placement
@export var emergency_loot_distance: int = 2

## Distance to move blocking enemies
@export var enemy_reposition_distance: int = 2

## Safe distance when repositioning enemies
@export var min_enemy_safe_distance: int = 4

## How many attempts to find safe enemy position
@export var enemy_position_attempts: int = 20

## Radius for escape route clearing
@export var escape_route_radius: int = 1

## Radius for checking available actions
@export var action_check_radius: int = 2

## Maximum loot actions to count for deadlock calculation
@export var max_loot_actions_counted: int = 3

# ================================
# 🎮 GAMEPLAY BALANCE PARAMETERS
# ================================

## Risk vs Reward scaling
@export var risk_reward_scaling: float = 1.0  # Multiplier for high-value loot placement

## Match-3 encouragement (higher = more clusters)  
@export var match3_encouragement: float = 1.0  # Multiplier for chain starter placement

## Exploration incentive (spread loot to encourage movement)
@export var exploration_incentive: float = 1.0  # Affects loot spread across field

## Progressive difficulty (place better loot further from spawn)
@export var progressive_difficulty_enabled: bool = true
@export var progression_distance_scaling: float = 0.1  # How much distance affects loot quality

# ================================
# 🔍 DEBUG AND MONITORING
# ================================

## Print detailed generation statistics
@export var debug_generation_stats: bool = true

## Print cluster formation details
@export var debug_cluster_formation: bool = false

## Print corridor reservation details  
@export var debug_corridor_system: bool = false

## Print deadlock monitoring info
@export var debug_deadlock_system: bool = true

# ================================
# 🚀 ADVANCED FEATURES
# ================================

## Dynamic loot adjustment based on player performance
@export var adaptive_difficulty_enabled: bool = false
@export var performance_tracking_window: int = 10  # Last N actions to consider

## Seasonal/themed loot variations
@export var themed_generation_enabled: bool = false
@export var current_theme: String = "default"  # "dungeon", "forest", "desert", etc.

## Loot magnet system (attract similar types together)
@export var loot_magnet_strength: float = 0.3  # 0.0 = no attraction, 1.0 = strong clustering

# ================================
# 📊 HELPER FUNCTIONS
# ================================

func get_weighted_random_type(types: Array[String], weights: Array[float]) -> String:
	"""Select random type based on weights"""
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	var random_value = randf() * total_weight
	var cumulative_weight = 0.0
	
	for i in range(types.size()):
		cumulative_weight += weights[i]
		if random_value <= cumulative_weight:
			return types[i]
	
	return types[0]  # Fallback

func get_high_value_loot_type() -> String:
	return get_weighted_random_type(high_value_types, high_value_weights)

func get_chain_starter_loot_type() -> String:
	return get_weighted_random_type(chain_starter_types, chain_starter_weights)

func get_balanced_loot_type() -> String:
	return get_weighted_random_type(balanced_types, balanced_weights)

func get_filler_loot_type() -> String:
	return get_weighted_random_type(filler_types, filler_weights)

func get_enemy_loot_type() -> String:
	return get_weighted_random_type(enemy_loot_types, enemy_loot_weights)

func apply_difficulty_scaling(base_types: Array[String], distance_from_spawn: float) -> Array[String]:
	"""Modify loot types based on distance from player spawn (progressive difficulty)"""
	if not progressive_difficulty_enabled:
		return base_types
	
	var scaled_types = base_types.duplicate()
	var difficulty_factor = distance_from_spawn * progression_distance_scaling
	
	# Add more valuable items at greater distances
	if difficulty_factor > 0.5:
		scaled_types.append("sword")
	if difficulty_factor > 0.7:
		scaled_types.append("shield")
	
	return scaled_types

func get_strategic_distribution_adjusted() -> Dictionary:
	"""Get strategic distribution adjusted by balance parameters"""
	var adjusted = strategic_distribution_ratios.duplicate()
	
	# Apply risk-reward scaling
	adjusted["high_value"] *= risk_reward_scaling
	
	# Apply match-3 encouragement  
	adjusted["chain_starters"] *= match3_encouragement
	
	# Apply exploration incentive
	adjusted["medium_value"] *= exploration_incentive
	
	# Normalize to ensure sum ≈ 1.0
	var total = 0.0
	for value in adjusted.values():
		total += value
	
	for key in adjusted.keys():
		adjusted[key] = adjusted[key] / total
	
	return adjusted

# ================================
# 💾 SAVE/LOAD PRESETS  
# ================================

func save_preset(preset_name: String):
	"""Save current config as preset"""
	var config_dict = {
		"field_coverage_ratio": field_coverage_ratio,
		"corridor_reservation_frequency": corridor_reservation_frequency,
		"corridor_reservation_chance": corridor_reservation_chance,
		"strategic_distribution_ratios": strategic_distribution_ratios,
		"deadlock_check_interval": deadlock_check_interval,
		"max_stuck_time": max_stuck_time,
		# Add other important parameters as needed
	}
	
	var file = FileAccess.open("user://loot_presets/" + preset_name + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config_dict))
		file.close()
		print("Saved loot generation preset: ", preset_name)

func load_preset(preset_name: String) -> bool:
	"""Load config from preset"""
	var file = FileAccess.open("user://loot_presets/" + preset_name + ".json", FileAccess.READ)
	if not file:
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		return false
	
	var config_dict = json.data
	
	# Apply loaded values
	field_coverage_ratio = config_dict.get("field_coverage_ratio", field_coverage_ratio)
	corridor_reservation_frequency = config_dict.get("corridor_reservation_frequency", corridor_reservation_frequency) 
	corridor_reservation_chance = config_dict.get("corridor_reservation_chance", corridor_reservation_chance)
	strategic_distribution_ratios = config_dict.get("strategic_distribution_ratios", strategic_distribution_ratios)
	deadlock_check_interval = config_dict.get("deadlock_check_interval", deadlock_check_interval)
	max_stuck_time = config_dict.get("max_stuck_time", max_stuck_time)
	
	print("Loaded loot generation preset: ", preset_name)
	return true

# ================================
# 🎮 PRESET CONFIGURATIONS
# ================================

func apply_easy_mode():
	"""Apply settings for easier gameplay"""
	field_coverage_ratio = 0.85
	strategic_distribution_ratios["easy_access"] = 0.35
	strategic_distribution_ratios["high_value"] = 0.10
	max_stuck_time = 5.0
	print("Applied EASY MODE loot generation settings")

func apply_hard_mode():
	"""Apply settings for challenging gameplay"""  
	field_coverage_ratio = 0.60
	strategic_distribution_ratios["high_value"] = 0.25
	strategic_distribution_ratios["easy_access"] = 0.10
	max_stuck_time = 15.0
	corridor_reservation_chance = 0.3
	print("Applied HARD MODE loot generation settings")

func apply_match3_focused():
	"""Optimize for match-3 gameplay"""
	strategic_distribution_ratios["chain_starters"] = 0.40
	max_chain_cluster_size = 8
	chain_cluster_spacing = 2
	match3_encouragement = 1.5
	print("Applied MATCH-3 FOCUSED loot generation settings")

func apply_exploration_focused():
	"""Optimize for exploration gameplay"""
	exploration_incentive = 1.5
	progressive_difficulty_enabled = true  
	strategic_distribution_ratios["medium_value"] = 0.50
	corridor_reservation_chance = 0.15
	print("Applied EXPLORATION FOCUSED loot generation settings")