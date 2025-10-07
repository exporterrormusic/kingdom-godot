extends Node2D
class_name EnvironmentController

signal environment_changed(biome_id: StringName, time_id: StringName)

@export var biome_definitions: Array[BiomeDefinition] = []
@export var time_of_day_definitions: Array[TimeOfDayDefinition] = []
@export_range(512.0, 8192.0, 16.0) var ground_extent: float = 4096.0
@export_range(0, 2147483647, 1) var environment_seed: int = 0
@export var auto_initialize: bool = true
@export var use_fixed_seed: bool = false

const GROUND_SHADER_PATH := "res://resources/shaders/procedural_ground.gdshader"
const SNOW_SHADER_PATH := "res://resources/shaders/falling_snow.gdshader"
const SNOW_IMPRINT_TEXTURE_SIZE := 1024
const SNOW_IMPRINT_DEFAULT := 0.5
const SNOW_FOOTPRINT_FADE := 0.8
const SNOW_PATH_RADIUS := 120.0
const SNOW_PARTICLE_LIFETIME := 0.55
const SNOW_PARTICLE_GRAVITY := 420.0

var _active_biome: BiomeDefinition = null
var _active_time: TimeOfDayDefinition = null
var _rng := RandomNumberGenerator.new()
var _time_flow: float = 0.0
var _biome_lookup: Dictionary = {}
var _time_lookup: Dictionary = {}
var _decoration_entries: Array[Dictionary] = []
var _effective_ground_extent: float = 0.0
var _snow_imprint_image: Image = null
var _snow_imprint_texture: ImageTexture = null
var _snow_imprint_enabled: bool = false
var _snow_particle_texture: Texture2D = null

@onready var _background: Polygon2D = _ensure_background()
@onready var _ground: Polygon2D = _ensure_ground()
@onready var _decor_container: Node2D = _ensure_decor_container()
@onready var _fog_overlay: ColorRect = _ensure_fog_overlay()
@onready var _overlay_canvas: CanvasLayer = _ensure_overlay_canvas()
@onready var _snow_overlay: ColorRect = _ensure_snow_overlay()
@onready var _snow_pile_container: Node2D = _ensure_snow_pile_container()
@onready var _snow_particle_container: Node2D = _ensure_snow_particle_container()
@onready var _canvas_modulate: CanvasModulate = _ensure_canvas_modulate()
@onready var _sun_light: DirectionalLight2D = _ensure_sun_light()

func _ready() -> void:
	_update_ground_geometry()
	_rebuild_lookups()
	_configure_rng(environment_seed)
	if auto_initialize:
		initialize_environment(environment_seed if use_fixed_seed else 0)
	set_process(true)
	var viewport := get_viewport()
	if viewport:
		viewport.size_changed.connect(_on_viewport_size_changed)
	_update_overlay_layout()

func _process(delta: float) -> void:
	_time_flow += delta
	var shader_material := _get_shader_material()
	if shader_material:
		shader_material.set_shader_parameter("time_flow", _time_flow)
		if _active_biome:
			shader_material.set_shader_parameter("wind_strength", _active_biome.wind_strength)
	if _snow_overlay and _snow_overlay.material and _snow_overlay.visible:
		var snow_material := _snow_overlay.material as ShaderMaterial
		if snow_material:
			snow_material.set_shader_parameter("time_flow", _time_flow)
			snow_material.set_shader_parameter("view_size", _get_view_size())
			var wind_dir := Vector2(_active_biome.wind_strength if _active_biome else 0.4, -1.0)
			snow_material.set_shader_parameter("wind_direction", wind_dir)
			snow_material.set_shader_parameter("world_offset", _compute_camera_world_offset())
	_update_decoration_animations(delta)

func initialize_environment(seed_override: int = 0, biome_id: StringName = &"", time_id: StringName = &"") -> void:
	_configure_rng(seed_override)
	_active_biome = _select_biome(biome_id)
	_active_time = _select_time_of_day(time_id)
	_apply_biome_to_ground()
	_apply_time_of_day_settings()
	_spawn_decorations()
	emit_signal("environment_changed", _get_biome_id(), _get_time_id())

func set_environment(biome_id: StringName, time_id: StringName, seed_override: int = 0) -> void:
	initialize_environment(seed_override, biome_id, time_id)

func refresh(seed_override: int = -1) -> void:
	if seed_override >= 0:
		environment_seed = seed_override
	initialize_environment(environment_seed if use_fixed_seed else 0, _get_biome_id(), _get_time_id())

func get_active_biome() -> BiomeDefinition:
	return _active_biome

func get_active_time_of_day() -> TimeOfDayDefinition:
	return _active_time

func _configure_rng(seed_value: int) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

func _rebuild_lookups() -> void:
	_biome_lookup.clear()
	_time_lookup.clear()
	for biome in biome_definitions:
		if biome == null:
			continue
		var key := biome.biome_id if biome.biome_id != &"" else StringName(biome.display_name.to_lower())
		_biome_lookup[key] = biome
	for tod in time_of_day_definitions:
		if tod == null:
			continue
		var key := tod.time_id if tod.time_id != &"" else StringName(tod.display_name.to_lower())
		_time_lookup[key] = tod

func _select_biome(requested_id: StringName) -> BiomeDefinition:
	if requested_id != &"" and _biome_lookup.has(requested_id):
		return _biome_lookup[requested_id]
	if biome_definitions.is_empty():
		return null
	return biome_definitions[_rng.randi_range(0, biome_definitions.size() - 1)]

func _select_time_of_day(requested_id: StringName) -> TimeOfDayDefinition:
	if requested_id != &"" and _time_lookup.has(requested_id):
		return _time_lookup[requested_id]
	if time_of_day_definitions.is_empty():
		return null
	return time_of_day_definitions[_rng.randi_range(0, time_of_day_definitions.size() - 1)]

func _get_biome_id() -> StringName:
	return _active_biome.biome_id if _active_biome and _active_biome.biome_id != &"" else StringName("")

func _get_time_id() -> StringName:
	return _active_time.time_id if _active_time and _active_time.time_id != &"" else StringName("")

func _ensure_background() -> Polygon2D:
	var node := get_node_or_null("Background")
	if node and node is Polygon2D:
		return node
	var background := Polygon2D.new()
	background.name = "Background"
	background.z_index = -200
	background.color = Color(0.2, 0.3, 0.4, 1.0)
	add_child(background)
	return background

func _ensure_ground() -> Polygon2D:
	var node := get_node_or_null("Ground")
	if node and node is Polygon2D:
		return node
	var ground := Polygon2D.new()
	ground.name = "Ground"
	ground.z_index = -150
	ground.color = Color.WHITE
	add_child(ground)
	return ground

func _ensure_decor_container() -> Node2D:
	var node := get_node_or_null("DecorContainer")
	if node and node is Node2D:
		return node
	var container := Node2D.new()
	container.name = "DecorContainer"
	container.z_index = -50
	add_child(container)
	return container

func _ensure_fog_overlay() -> ColorRect:
	var node := get_node_or_null("FogOverlay")
	if node and node is ColorRect:
		return node
	var fog := ColorRect.new()
	fog.name = "FogOverlay"
	fog.color = Color(0.8, 0.85, 0.95, 0.0)
	fog.size = Vector2.ONE * _get_effective_ground_extent()
	fog.position = -fog.size * 0.5
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)
	return fog

func _ensure_overlay_canvas() -> CanvasLayer:
	var node := get_node_or_null("EnvironmentOverlay")
	if node and node is CanvasLayer:
		return node
	var layer := CanvasLayer.new()
	layer.name = "EnvironmentOverlay"
	layer.layer = 0
	add_child(layer)
	if Engine.is_editor_hint():
		layer.owner = get_tree().edited_scene_root
	return layer

func _ensure_snow_overlay() -> ColorRect:
	if _overlay_canvas == null:
		return null
	var node := _overlay_canvas.get_node_or_null("SnowOverlay")
	if node and node is ColorRect:
		return node
	var snow := ColorRect.new()
	snow.name = "SnowOverlay"
	snow.color = Color(1.0, 1.0, 1.0, 0.0)
	snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snow.z_index = 50
	snow.anchor_left = 0.0
	snow.anchor_top = 0.0
	snow.anchor_right = 1.0
	snow.anchor_bottom = 1.0
	snow.offset_left = 0.0
	snow.offset_top = 0.0
	snow.offset_right = 0.0
	snow.offset_bottom = 0.0
	var view_size := _get_view_size()
	snow.custom_minimum_size = view_size
	var shader := load(SNOW_SHADER_PATH)
	if shader:
		var snow_shader_material := ShaderMaterial.new()
		snow_shader_material.shader = shader
		snow.material = snow_shader_material
		snow_shader_material.set_shader_parameter("view_size", view_size)
	else:
		snow.visible = false
	_overlay_canvas.add_child(snow)
	if Engine.is_editor_hint():
		snow.owner = get_tree().edited_scene_root
	return snow

func _ensure_snow_pile_container() -> Node2D:
	var node := get_node_or_null("SnowPiles")
	if node and node is Node2D:
		return node
	var container := Node2D.new()
	container.name = "SnowPiles"
	container.z_index = -45
	add_child(container)
	if Engine.is_editor_hint():
		container.owner = get_tree().edited_scene_root
	return container

func _ensure_snow_particle_container() -> Node2D:
	var node := get_node_or_null("SnowParticles")
	if node and node is Node2D:
		return node
	var container := Node2D.new()
	container.name = "SnowParticles"
	container.z_index = -40
	add_child(container)
	if Engine.is_editor_hint():
		container.owner = get_tree().edited_scene_root
	return container

func _ensure_canvas_modulate() -> CanvasModulate:
	var node := get_node_or_null("CanvasModulate")
	if node and node is CanvasModulate:
		return node
	var mod := CanvasModulate.new()
	mod.name = "CanvasModulate"
	mod.color = Color(1.0, 1.0, 1.0, 1.0)
	add_child(mod)
	return mod

func _ensure_sun_light() -> DirectionalLight2D:
	var node := get_node_or_null("SunLight")
	if node and node is DirectionalLight2D:
		return node
	var sun := DirectionalLight2D.new()
	sun.name = "SunLight"
	sun.color = Color(1.0, 0.95, 0.85, 1.0)
	sun.energy = 1.0
	sun.rotation = Vector2(-0.5, 1.0).angle()
	sun.editor_only = false
	add_child(sun)
	sun.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null
	return sun

func _update_ground_geometry() -> void:
	var view_size := _get_view_size()
	var dynamic_extent := maxf(ground_extent, maxf(view_size.x, view_size.y) * 6.0)
	_effective_ground_extent = dynamic_extent
	var half := _effective_ground_extent * 0.5
	var polygon := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half)
	])
	var uv_scale := _effective_ground_extent / 512.0
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(uv_scale, 0.0),
		Vector2(uv_scale, uv_scale),
		Vector2(0.0, uv_scale)
	])
	if _ground:
		_ground.polygon = polygon
		_ground.uv = uvs
		_ground.offset = Vector2.ZERO
	var sky_half := _effective_ground_extent * 0.75
	var sky_polygon := PackedVector2Array([
		Vector2(-sky_half, -sky_half),
		Vector2(sky_half, -sky_half),
		Vector2(sky_half, sky_half),
		Vector2(-sky_half, sky_half)
	])
	if _background:
		_background.polygon = sky_polygon
		_background.uv = uvs
	if _fog_overlay:
		_fog_overlay.size = Vector2.ONE * _effective_ground_extent
		_fog_overlay.position = -_fog_overlay.size * 0.5
	_update_overlay_layout()

func _get_shader_material() -> ShaderMaterial:
	if not _ground:
		return null
	if _ground.material and _ground.material is ShaderMaterial:
		return _ground.material
	var shader := load(GROUND_SHADER_PATH)
	if shader == null:
		return null
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	_ground.material = shader_material
	return shader_material

func _apply_biome_to_ground() -> void:
	var shader_material := _get_shader_material()
	if not shader_material:
		return
	var biome := _active_biome
	if biome == null:
		shader_material.set_shader_parameter("base_color", Color(0.22, 0.28, 0.3, 1.0))
		shader_material.set_shader_parameter("secondary_color", Color(0.18, 0.24, 0.28, 1.0))
		shader_material.set_shader_parameter("accent_color", Color(0.35, 0.4, 0.48, 1.0))
		shader_material.set_shader_parameter("noise_scale", 6.0)
		shader_material.set_shader_parameter("detail_strength", 0.35)
		shader_material.set_shader_parameter("wave_strength", 0.12)
		shader_material.set_shader_parameter("wave_speed", 0.45)
		shader_material.set_shader_parameter("patchwork_strength", 0.3)
		shader_material.set_shader_parameter("color_variation", 0.2)
		shader_material.set_shader_parameter("snow_cover", 0.0)
		shader_material.set_shader_parameter("snow_brightness", 1.0)
		shader_material.set_shader_parameter("snow_tint_color", Vector3(0.86, 0.92, 1.0))
		shader_material.set_shader_parameter("snow_tint_strength", 0.0)
		shader_material.set_shader_parameter("snow_shadow_strength", 0.0)
		shader_material.set_shader_parameter("snow_drift_scale", 0.6)
		shader_material.set_shader_parameter("snow_crust_strength", 0.0)
		shader_material.set_shader_parameter("snow_ice_highlight", 0.0)
		shader_material.set_shader_parameter("snow_sparkle_intensity", 0.0)
		_apply_snow_overlay_settings(null)
		_configure_snow_imprint_state(null)
		return
	shader_material.set_shader_parameter("base_color", biome.base_color)
	shader_material.set_shader_parameter("secondary_color", biome.secondary_color)
	shader_material.set_shader_parameter("accent_color", biome.accent_color)
	shader_material.set_shader_parameter("noise_scale", biome.noise_scale)
	shader_material.set_shader_parameter("detail_strength", biome.detail_strength)
	shader_material.set_shader_parameter("wave_strength", biome.wave_strength)
	shader_material.set_shader_parameter("wave_speed", biome.wave_speed)
	shader_material.set_shader_parameter("patchwork_strength", biome.patchwork_strength)
	shader_material.set_shader_parameter("color_variation", biome.color_variation)
	shader_material.set_shader_parameter("wind_strength", biome.wind_strength)
	shader_material.set_shader_parameter("snow_cover", biome.snow_cover)
	shader_material.set_shader_parameter("snow_brightness", biome.snow_brightness)
	shader_material.set_shader_parameter("snow_tint_color", Vector3(biome.snow_tint_color.r, biome.snow_tint_color.g, biome.snow_tint_color.b))
	shader_material.set_shader_parameter("snow_tint_strength", biome.snow_tint_strength)
	shader_material.set_shader_parameter("snow_shadow_strength", biome.snow_shadow_strength)
	shader_material.set_shader_parameter("snow_drift_scale", biome.snow_drift_scale)
	shader_material.set_shader_parameter("snow_crust_strength", biome.snow_crust_strength)
	shader_material.set_shader_parameter("snow_ice_highlight", biome.snow_ice_highlight)
	shader_material.set_shader_parameter("snow_sparkle_intensity", biome.snow_sparkle_intensity)
	if _background:
		_background.color = biome.sky_color
	_apply_snow_overlay_settings(biome)
	_configure_snow_imprint_state(biome)

func _apply_time_of_day_settings() -> void:
	var is_default_day := _active_time != null and _active_time.time_id == &"day"
	if is_default_day:
		if _canvas_modulate:
			_canvas_modulate.color = Color(1.0, 1.0, 1.0, 1.0)
		if _fog_overlay:
			_fog_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
		if _background:
			if _active_biome:
				_background.color = _active_biome.sky_color
			else:
				_background.color = Color(1.0, 1.0, 1.0, 1.0)
		if _sun_light:
			_sun_light.visible = false
			_sun_light.energy = 0.0
		return
	if _canvas_modulate and _active_time:
		_canvas_modulate.color = _active_time.get_canvas_modulate()
	elif _canvas_modulate:
		_canvas_modulate.color = Color(1.0, 1.0, 1.0, 1.0)
	if _fog_overlay:
		if _active_time:
			var fog_color := _active_time.fog_color
			fog_color.a = clamp(_active_time.fog_alpha, 0.0, 1.0)
			_fog_overlay.color = fog_color
		else:
			_fog_overlay.color = Color(0.8, 0.85, 0.95, 0.0)
	if _background and _active_time and _active_biome:
		var tint_strength: float = clamp(_active_time.ambient_intensity, 0.0, 1.5)
		var target := _active_biome.sky_color.lerp(_active_biome.horizon_color, 0.35)
		_background.color = target.lerp(_active_time.sky_tint, tint_strength * 0.5)
	elif _background and _active_time:
		_background.color = _active_time.sky_tint
	if _sun_light:
		if _active_time:
			_sun_light.visible = true
			_sun_light.color = _active_time.light_color
			_sun_light.energy = maxf(0.0, _active_time.light_energy)
			var angle := deg_to_rad(_active_time.light_angle_degrees)
			_sun_light.rotation = angle
		else:
			_sun_light.color = Color(1.0, 0.96, 0.85, 1.0)
			_sun_light.energy = 1.0

func _spawn_decorations() -> void:
	for entry in _decoration_entries:
		var node: Node2D = entry.get("node")
		if node and is_instance_valid(node):
			node.queue_free()
	_decoration_entries.clear()
	if _decor_container == null:
		return
	if _active_biome == null or not _active_biome.has_decorations():
		return
	var radius: float = maxf(_active_biome.decoration_spawn_radius, _get_effective_ground_extent() * 0.45)
	for i in range(_active_biome.decoration_count):
		var texture: Texture2D = _active_biome.decoration_textures[_rng.randi_range(0, _active_biome.decoration_textures.size() - 1)]
		if texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.z_index = -40
		sprite.position = _random_point_in_circle(radius)
		var scale_factor := lerpf(_active_biome.decoration_min_scale, _active_biome.decoration_max_scale, _rng.randf())
		sprite.scale = Vector2.ONE * scale_factor
		sprite.rotation = _rng.randf_range(-0.35, 0.35)
		sprite.modulate = Color(1.0, 1.0, 1.0, _active_biome.decoration_alpha)
		_decor_container.add_child(sprite)
		_decoration_entries.append({
			"node": sprite,
			"phase": _rng.randf_range(0.0, TAU),
			"base_rotation": sprite.rotation,
			"base_scale": sprite.scale
		})

func _random_point_in_circle(radius: float) -> Vector2:
	var angle := _rng.randf_range(0.0, TAU)
	var distance := sqrt(_rng.randf()) * radius
	return Vector2(cos(angle), sin(angle)) * distance

func _update_decoration_animations(delta: float) -> void:
	if _decoration_entries.is_empty():
		return
	if _active_biome == null:
		return
	for entry in _decoration_entries:
		var sprite: Sprite2D = entry.get("node")
		if sprite == null or not is_instance_valid(sprite):
			continue
		var phase: float = float(entry.get("phase", 0.0))
		phase += delta * (_active_biome.wind_strength * 0.75 + 0.25)
		entry["phase"] = phase
		var sway := sin(phase) * 0.2 * _active_biome.decoration_variation
		sprite.rotation = float(entry.get("base_rotation", 0.0)) + sway
		var base_scale: Vector2 = entry.get("base_scale", Vector2.ONE)
		var scale_wave := 1.0 + sin(phase * 1.7) * 0.05 * _active_biome.decoration_variation
		sprite.scale = base_scale * scale_wave

func _apply_snow_overlay_settings(biome: BiomeDefinition) -> void:
	if _snow_overlay == null:
		return
	var snow_material := _snow_overlay.material as ShaderMaterial
	if snow_material == null:
		_snow_overlay.visible = false
		return
	if biome == null or biome.snowfall_density <= 0.0:
		_snow_overlay.visible = false
		snow_material.set_shader_parameter("density", 0.0)
		snow_material.set_shader_parameter("flake_scale", 1.0)
		snow_material.set_shader_parameter("view_size", _get_view_size())
		return
	_snow_overlay.visible = true
	var density_scale := clampf(biome.snowfall_density * 0.55 + 0.15, 0.0, 1.2)
	snow_material.set_shader_parameter("density", density_scale)
	var flake_scale := clampf(biome.snowfall_scale * 0.42, 0.18, 1.25)
	snow_material.set_shader_parameter("flake_scale", flake_scale)
	snow_material.set_shader_parameter("view_size", _get_view_size())
	snow_material.set_shader_parameter("world_offset", _compute_camera_world_offset())
	snow_material.set_shader_parameter("world_scale", 0.0025)

func _configure_snow_imprint_state(biome: BiomeDefinition) -> void:
	var shader_material := _get_shader_material()
	if shader_material == null:
		return
	if biome == null or biome.snow_cover <= 0.05:
		_snow_imprint_enabled = false
		shader_material.set_shader_parameter("snow_imprint_strength", 0.0)
		_clear_snow_imprint()
		_clear_snow_piles()
		return
	_ensure_snow_imprint_resources()
	_snow_imprint_enabled = true
	shader_material.set_shader_parameter("snow_imprint_texture", _snow_imprint_texture)
	shader_material.set_shader_parameter("snow_imprint_texel_size", Vector2(1.0 / SNOW_IMPRINT_TEXTURE_SIZE, 1.0 / SNOW_IMPRINT_TEXTURE_SIZE))
	shader_material.set_shader_parameter("snow_imprint_strength", clampf(biome.snow_cover * 1.1, 0.2, 2.0))
	_clear_snow_imprint()
	_clear_snow_piles()

func _ensure_snow_imprint_resources() -> void:
	if _snow_imprint_image != null and _snow_imprint_texture != null:
		return
	_snow_imprint_image = Image.create(SNOW_IMPRINT_TEXTURE_SIZE, SNOW_IMPRINT_TEXTURE_SIZE, false, Image.FORMAT_RF)
	_snow_imprint_image.fill(Color(SNOW_IMPRINT_DEFAULT, SNOW_IMPRINT_DEFAULT, SNOW_IMPRINT_DEFAULT, 1.0))
	_snow_imprint_texture = ImageTexture.create_from_image(_snow_imprint_image)
	var shader_material := _get_shader_material()
	if shader_material:
		shader_material.set_shader_parameter("snow_imprint_texture", _snow_imprint_texture)
		shader_material.set_shader_parameter("snow_imprint_texel_size", Vector2(1.0 / SNOW_IMPRINT_TEXTURE_SIZE, 1.0 / SNOW_IMPRINT_TEXTURE_SIZE))

func _clear_snow_imprint(value: float = SNOW_IMPRINT_DEFAULT) -> void:
	if _snow_imprint_image == null:
		return
	_snow_imprint_image.fill(Color(value, value, value, 1.0))
	if _snow_imprint_texture:
		_snow_imprint_texture.update(_snow_imprint_image)

func _clear_snow_piles() -> void:
	if _snow_pile_container == null:
		return
	for child in _snow_pile_container.get_children():
		child.queue_free()

func _seed_snow_piles(biome: BiomeDefinition) -> void:
	_clear_snow_piles()
	if not _snow_imprint_enabled or biome == null:
		return
	var pile_count := int(roundi(lerpf(6.0, 18.0, clampf(biome.snowfall_density, 0.0, 1.0))))
	for i in range(pile_count):
		var extent := _get_effective_ground_extent()
		var radius := _rng.randf_range(extent * 0.03, extent * 0.08)
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(extent * 0.15, extent * 0.45)
		var local_position := Vector2.RIGHT.rotated(angle) * distance
		_add_snow_stamp(local_position, radius, _rng.randf_range(0.35, 0.65))
		if _snow_pile_container:
			var pile: SnowPile = SnowPile.new()
			pile.position = local_position
			pile.radius = radius
			pile.height = radius * 0.65
			_snow_pile_container.add_child(pile)
			if Engine.is_editor_hint():
				pile.owner = get_tree().edited_scene_root

func _add_snow_stamp(local_position: Vector2, radius: float, delta: float) -> void:
	if not _snow_imprint_enabled or _snow_imprint_image == null:
		return
	var extent := _get_effective_ground_extent()
	var half_extent := extent * 0.5
	var uv := Vector2(
		(local_position.x + half_extent) / extent,
		(local_position.y + half_extent) / extent
	)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return
	var center_px := Vector2i(
		int(round(clampf(uv.x, 0.0, 1.0) * float(SNOW_IMPRINT_TEXTURE_SIZE - 1))),
		int(round(clampf(uv.y, 0.0, 1.0) * float(SNOW_IMPRINT_TEXTURE_SIZE - 1)))
	)
	var radius_px := int(max(1.0, round((radius / extent) * float(SNOW_IMPRINT_TEXTURE_SIZE))))
	for y_offset in range(-radius_px, radius_px + 1):
		var py := center_px.y + y_offset
		if py < 0 or py >= SNOW_IMPRINT_TEXTURE_SIZE:
			continue
		for x_offset in range(-radius_px, radius_px + 1):
			var px := center_px.x + x_offset
			if px < 0 or px >= SNOW_IMPRINT_TEXTURE_SIZE:
				continue
			var dist := sqrt(float(x_offset * x_offset + y_offset * y_offset)) / float(radius_px)
			if dist > 1.0:
				continue
			var falloff := pow(clampf(1.0 - dist, 0.0, 1.0), 2.2)
			var current := _snow_imprint_image.get_pixel(px, py).r
			var target := clampf(current + delta * falloff, 0.0, 1.0)
			_snow_imprint_image.set_pixel(px, py, Color(target, target, target, 1.0))
	if _snow_imprint_texture:
		_snow_imprint_texture.update(_snow_imprint_image)

func supports_snow_imprints() -> bool:
	return _snow_imprint_enabled and _snow_imprint_image != null

func add_snow_footprint(world_position: Vector2, radius: float = 80.0, depth: float = SNOW_FOOTPRINT_FADE) -> void:
	if not supports_snow_imprints():
		return
	var local := to_local(world_position)
	_add_snow_stamp(local, radius, -abs(depth))
	_add_snow_stamp(local, radius * 1.35, abs(depth) * 0.18)
	_emit_snow_particles(world_position, abs(depth))

func add_snow_path_sample(world_position: Vector2, radius: float = SNOW_PATH_RADIUS, depth: float = SNOW_FOOTPRINT_FADE) -> void:
	if not supports_snow_imprints():
		return
	var local := to_local(world_position)
	_add_snow_stamp(local, radius, -abs(depth))
	_add_snow_stamp(local, radius * 1.5, abs(depth) * 0.22)
	if depth > 0.3:
		_emit_snow_particles(world_position, abs(depth) * 0.6)
func add_snow_accumulation(world_position: Vector2, radius: float, height: float) -> void:
	if not supports_snow_imprints():
		return
	var local := to_local(world_position)
	_add_snow_stamp(local, radius, abs(height))

func emit_snow_kickup(world_position: Vector2, strength: float = 0.45) -> void:
	if not supports_snow_imprints():
		return
	_emit_snow_particles(world_position, clampf(strength, 0.0, 1.0))

func _update_overlay_layout() -> void:
	if _snow_overlay == null:
		return
	var view_size := _get_view_size()
	_snow_overlay.custom_minimum_size = view_size
	var snow_material := _snow_overlay.material as ShaderMaterial
	if snow_material:
		snow_material.set_shader_parameter("view_size", view_size)

func _on_viewport_size_changed() -> void:
	_update_overlay_layout()

func _get_view_size() -> Vector2:
	var viewport := get_viewport()
	if viewport:
		return viewport.get_visible_rect().size
	return Vector2(1920.0, 1080.0)

func _compute_camera_world_offset() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var camera := viewport.get_camera_2d()
	if camera == null:
		return Vector2.ZERO
	var zoom := camera.zoom
	var view_size := viewport.get_visible_rect().size * zoom
	return camera.global_position - view_size * 0.5

func _get_effective_ground_extent() -> float:
	return maxf(_effective_ground_extent, ground_extent)

func _emit_snow_particles(world_position: Vector2, strength: float) -> void:
	if _snow_particle_container == null:
		return
	var texture := _get_snow_particle_texture()
	var particles := GPUParticles2D.new()
	particles.one_shot = true
	particles.amount = int(round(clampf(lerpf(10.0, 22.0, clampf(strength, 0.0, 1.0)), 6.0, 28.0)))
	particles.lifetime = SNOW_PARTICLE_LIFETIME
	particles.explosiveness = 0.6
	particles.speed_scale = 1.0
	particles.texture = texture
	particles.process_material = _create_snow_particle_material(strength)
	particles.global_position = world_position
	_snow_particle_container.add_child(particles)
	particles.finished.connect(Callable(particles, "queue_free"))
	particles.emitting = true

func _create_snow_particle_material(strength: float) -> ParticleProcessMaterial:
	var particle_material := ParticleProcessMaterial.new()
	particle_material.gravity = Vector3(0.0, SNOW_PARTICLE_GRAVITY, 0.0)
	var intensity := clampf(strength, 0.0, 1.0)
	var velocity := lerpf(80.0, 160.0, intensity)
	particle_material.initial_velocity_min = velocity * 0.5
	particle_material.initial_velocity_max = velocity
	particle_material.direction = Vector3(0.0, -1.0, 0.0)
	particle_material.spread = 65.0
	particle_material.angular_velocity_min = -8.0
	particle_material.angular_velocity_max = 8.0
	particle_material.scale_min = 0.38
	particle_material.scale_max = 0.72
	particle_material.damping_min = 1.2
	particle_material.damping_max = 3.6
	particle_material.color_ramp = _get_snow_particle_ramp()
	return particle_material

func _get_snow_particle_texture() -> Texture2D:
	if _snow_particle_texture != null:
		return _snow_particle_texture
	var size := 16
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := float(x) / float(size - 1)
			var v := float(y) / float(size - 1)
			var dx := u - 0.5
			var dy := v - 0.5
			var dist := sqrt(dx * dx + dy * dy) * 2.2
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			var color := Color(0.96, 0.99, 1.0, pow(alpha, 1.5) * 0.9)
			image.set_pixel(x, y, color)
	_snow_particle_texture = ImageTexture.create_from_image(image)
	return _snow_particle_texture

func _get_snow_particle_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.95, 0.98, 1.0, 0.75),
		Color(0.95, 0.98, 1.0, 0.35),
		Color(0.95, 0.98, 1.0, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp
