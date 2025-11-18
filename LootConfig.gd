class_name LootConfig
extends Resource

# Loot collection configuration settings
@export var collection_delay: float = 0.3      # Seconds to wait before collecting loot after passing through
@export var collection_animation_time: float = 0.2  # Time for loot disappearance animation
@export var collection_effect_scale: float = 1.5    # Scale multiplier for collection effect
@export var show_collection_particles: bool = true   # Whether to show particle effects
@export var collection_sound_enabled: bool = true    # Whether to play collection sounds

# Visual feedback settings
@export var highlight_collected_tiles: bool = true   # Highlight tiles where loot was collected
@export var highlight_duration: float = 0.5          # How long to show tile highlights

func _init():
	# Set default values for "comet tail" collection effect
	collection_delay = 0.2           # Small delay to create trailing effect
	collection_animation_time = 0.8   # Longer fade for smooth comet tail
	collection_effect_scale = 1.2    # Subtle scale change
	show_collection_particles = true
	collection_sound_enabled = true
	highlight_collected_tiles = true
	highlight_duration = 0.6         # Match fade duration