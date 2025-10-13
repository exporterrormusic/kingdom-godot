extends Resource
class_name CharacterData

@export var code_name: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var role: String = "Balanced"
@export var difficulty: String = "Standard"

# Core movement/combat tuning used by gameplay.
@export var move_speed: float = 400.0
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.2
@export var fire_rate: float = 0.25
@export var projectile_speed: float = 1200.0
@export var projectile_lifetime: float = 0.75
@export var projectile_damage: int = 1
@export var projectile_radius: float = 4.0
@export var projectile_color: Color = Color(1.0, 0.9, 0.4, 1.0)
@export var projectile_penetration: int = 1
@export var projectile_range: float = 800.0
@export var projectile_shape: String = "standard"

@export var fire_mode: String = "automatic"
@export var magazine_size: int = 30
@export var reload_time: float = 2.0
@export var grenade_rounds: int = 0
@export var grenade_reload_time: float = 0.0
@export var pellet_count: int = 1
@export var spread_angle: float = 0.0
@export var special_mechanics: Dictionary = {}
@export var special_attack_data: Dictionary = {}

# High-level stat summary displayed in the character select detail panel.
@export var hp: int = 250
@export var attack: int = 75
@export var speed_rating: int = 250
@export var burst_rating: int = 5

# Weapon overview content.
@export var weapon_name: String = "Standard-Issue"
@export var weapon_type: String = "Assault Rifle"
@export_multiline var weapon_description: String = "Reliable weapon with balanced cadence."
@export var weapon_special_name: String = "Overclock"
@export_multiline var weapon_special_description: String = "Temporarily boosts rate of fire after sustained fire."

# Burst ability overview content.
@export var burst_name: String = "Burst Protocol"
@export_multiline var burst_description: String = "Unleash concentrated firepower that pierces enemies in a line."
@export var burst_damage_multiplier: float = 2.0
@export var burst_max_points: float = 100.0
@export var burst_points_per_enemy: float = 10.0
@export var burst_points_per_hit: float = 1.0

# Visual assets for the menu presentation.
@export var portrait_texture: Texture2D
@export var burst_texture: Texture2D
@export var sprite_sheet: Texture2D
@export var sprite_sheet_columns: int = 1
@export var sprite_sheet_rows: int = 1
@export var sprite_animation_fps: float = 6.0
@export var sprite_scale: float = 0.2

func summary() -> String:
	return "%s — %s" % [display_name, role]

func has_sprite_animation() -> bool:
	return sprite_sheet != null and sprite_sheet_columns > 0 and sprite_sheet_rows > 0 and sprite_sheet_columns * sprite_sheet_rows > 1
