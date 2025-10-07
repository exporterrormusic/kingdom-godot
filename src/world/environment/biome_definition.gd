extends Resource
class_name BiomeDefinition

## Describes shader, palette, and decoration rules for a biome.
@export var biome_id: StringName = &""
@export var display_name: String = "Biome"
@export var base_color: Color = Color(0.25, 0.35, 0.25, 1.0)
@export var secondary_color: Color = Color(0.16, 0.24, 0.16, 1.0)
@export var accent_color: Color = Color(0.5, 0.59, 0.45, 1.0)
@export_range(1.0, 24.0, 0.1) var noise_scale: float = 6.0
@export_range(0.0, 1.0, 0.01) var detail_strength: float = 0.35
@export_range(0.0, 1.0, 0.01) var wave_strength: float = 0.18
@export_range(0.0, 2.0, 0.01) var wave_speed: float = 0.6
@export_range(0.0, 1.0, 0.01) var patchwork_strength: float = 0.4
@export_range(0.0, 1.0, 0.01) var color_variation: float = 0.25
@export var sky_color: Color = Color(0.25, 0.38, 0.52, 1.0)
@export var horizon_color: Color = Color(0.32, 0.42, 0.47, 1.0)
@export var decoration_textures: Array[Texture2D] = []
@export_range(0, 256, 1) var decoration_count: int = 64
@export_range(0.2, 4.0, 0.01) var decoration_min_scale: float = 0.75
@export_range(0.2, 4.0, 0.01) var decoration_max_scale: float = 1.35
@export_range(0.0, 1.0, 0.01) var decoration_alpha: float = 0.88
@export_range(0.0, 720.0, 1.0) var decoration_spawn_radius: float = 560.0
@export_range(0.0, 1.0, 0.01) var decoration_variation: float = 0.35
@export_range(0.0, 5.0, 0.01) var wind_strength: float = 0.45
@export_range(0.0, 1.0, 0.01) var snow_cover: float = 0.0
@export_range(0.5, 2.0, 0.01) var snow_brightness: float = 1.0
@export var snow_tint_color: Color = Color(0.86, 0.92, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var snow_tint_strength: float = 0.08
@export_range(0.0, 1.0, 0.01) var snow_shadow_strength: float = 0.18
@export_range(0.0, 2.0, 0.01) var snow_drift_scale: float = 0.6
@export_range(0.0, 1.0, 0.01) var snow_crust_strength: float = 0.3
@export_range(0.0, 1.0, 0.01) var snow_ice_highlight: float = 0.22
@export_range(0.0, 2.0, 0.01) var snow_sparkle_intensity: float = 0.2
@export_range(0.0, 2.0, 0.01) var snowfall_density: float = 0.0
@export_range(0.25, 4.0, 0.01) var snowfall_scale: float = 1.0

func has_decorations() -> bool:
	return decoration_textures.size() > 0 and decoration_count > 0
