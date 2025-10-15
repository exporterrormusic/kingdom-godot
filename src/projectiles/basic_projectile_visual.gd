@tool
extends Node2D
class_name BasicProjectileVisual

const StandardBulletVisualScene: PackedScene = preload("res://scenes/projectiles/visuals/StandardBulletVisual.tscn")
const StandardBulletVisualScript: Script = preload("res://src/projectiles/visuals/standard_bullet_visual.gd")

const WeaponVisualScenePaths := {
	"smg": "res://scenes/projectiles/visuals/weapons/SmgNormalBulletVisual.tscn",
	"smg_special": "res://scenes/projectiles/visuals/weapons/SmgSpecialBulletVisual.tscn",
	"minigun": "res://scenes/projectiles/visuals/weapons/MinigunBulletVisual.tscn",
	"minigun_special": "res://scenes/projectiles/visuals/weapons/MinigunSpecialBulletVisual.tscn",
	"assault": "res://scenes/projectiles/visuals/weapons/AssaultBulletVisual.tscn",
	"assault_special": "res://scenes/projectiles/visuals/weapons/AssaultSpecialBulletVisual.tscn",
	"shotgun": "res://scenes/projectiles/visuals/weapons/ShotgunPelletVisual.tscn",
	"shotgun_special": "res://scenes/projectiles/visuals/weapons/ShotgunSpecialPelletVisual.tscn",
	"sniper": "res://scenes/projectiles/visuals/weapons/SniperBulletVisual.tscn",
	"sniper_special": "res://scenes/projectiles/visuals/weapons/SniperSpecialBulletVisual.tscn"
}

const BULLET_SHADER := preload("res://src/projectiles/shaders/bullet_circle.gdshader")
const LASER_LAYER_COUNT := 3
const LASER_CRACKLE_COUNT := 12
const PROJECTILE_BASE_Z_INDEX := 900

static var _ambient_compensation_strength: float = 1.0
static var _vignette_strength: float = 0.0
static var _vignette_inner_radius: float = 0.6
static var _vignette_softness: float = 0.4
static var _vignette_view_size: Vector2 = Vector2.ZERO
static var _is_day_time: bool = true

var _projectile: Node = null
static func _assign_canvas_layer(node: CanvasItem, z_offset: int = 0) -> void:
	if node == null:
		return
	node.z_as_relative = false
	node.z_index = PROJECTILE_BASE_Z_INDEX + z_offset
var _sprite: Sprite2D = null
var _trail: Line2D = null
var _tracer_body: Line2D = null
var _tracer_tip: Sprite2D = null
var _neon_glow: Line2D = null
var _neon_core: Line2D = null
var _neon_tip: Sprite2D = null
var _laser_layers: Array = []
var _laser_core: Polygon2D = null
var _laser_center_line: Line2D = null
var _laser_tip_glow: Sprite2D = null
var _laser_tip_highlight: Sprite2D = null
var _laser_tip_particles: GPUParticles2D = null
var _laser_crackles: Array = []
var _bounce_particles: GPUParticles2D = null
var _glow_sprite: Sprite2D = null
var _white_texture: Texture2D = null
var _trail_point_cache: PackedVector2Array = PackedVector2Array()
var _is_tracer: bool = false
var _is_neon: bool = false
var _glow_texture: Texture2D = null
var _is_laser: bool = false
var _is_pellet: bool = false
var _is_minigun: bool = false
var _is_standard: bool = false
var _trail_enabled: bool = false
var _bounce_visuals: bool = false
var _laser_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _glow_enabled: bool = false
var _glow_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _glow_energy: float = 1.0
var _glow_scale: float = 1.0
var _glow_height: float = 0.0
var _standard_visual: Node2D = null
var _is_editor_preview := false
var _weapon_visual: Node2D = null

func _ready() -> void:
	_white_texture = _create_white_texture()
	_laser_rng.randomize()
	z_as_relative = false
	z_index = PROJECTILE_BASE_Z_INDEX
	_is_editor_preview = Engine.is_editor_hint()
	if _is_editor_preview:
		_setup_editor_preview()

func setup(projectile: Node, bounce_visuals_enabled: bool) -> void:
	_projectile = projectile
	_bounce_visuals = bounce_visuals_enabled
	_clear_children()
	_setup_trail(projectile.shape.to_lower(), projectile.trail_color)
	var weapon_visual_created: bool = _setup_weapon_visual(projectile)
	var shape_key: String = String(projectile.shape).to_lower()
	var use_standard := false
	if shape_key == "" and projectile is BasicProjectile:
		shape_key = (projectile as BasicProjectile).shape.to_lower()
	if not weapon_visual_created:
		match shape_key:
			"tracer":
				_is_tracer = true
				_setup_tracer_body(projectile.color)
			"neon":
				_is_neon = true
				_setup_neon_body(projectile.color)
			"pellet":
				_is_pellet = true
				_setup_circle_body(projectile.color, false)
			"laser":
				_is_laser = true
				_setup_laser_body(projectile.color)
			_:
				_is_minigun = projectile.projectile_archetype.to_lower() == "minigun"
				use_standard = shape_key == "standard" or shape_key == ""
				_setup_circle_body(projectile.color, use_standard)
	if _bounce_visuals:
		_setup_bounce_particles(projectile.color)
	set_trail_enabled(projectile.trail_enabled)
	_ensure_glow_sprite()

func update_visual(trail_points: Array, direction: Vector2, radius: float, color: Color, has_bounced: bool) -> void:
	var weapon_context: Dictionary = _collect_weapon_visual_context(has_bounced)
	if _weapon_visual and _weapon_visual.has_method("update_visual"):
		_weapon_visual.call("update_visual", direction, radius, color, weapon_context)
	else:
		if _sprite:
			var desired_scale: float = max(radius * 1.4, 1.2)
			_sprite.scale = Vector2.ONE * desired_scale
			_update_circle_colors(color)
		if _is_standard and _standard_visual:
			if _standard_visual.has_method("configure"):
				_standard_visual.call("configure", color, radius)
			if direction.length() > 0.001:
				_standard_visual.rotation = direction.angle()
			else:
				_standard_visual.rotation = 0.0
		if _is_tracer and _tracer_body:
			_update_tracer_body(direction, radius, color)
		if _is_neon:
			_update_neon_body(direction, radius, color, has_bounced)
		if _is_laser:
			_update_laser_body(direction, radius, color)
	if _trail:
		_update_trail(trail_points)
	if _bounce_visuals and _bounce_particles:
		var tint := Color(1.0, 0.7, 0.25, 1.0) if has_bounced else Color(1.0, 0.9, 0.65, 1.0)
		_bounce_particles.modulate = _apply_color(tint)
	_update_glow_visual(direction, radius)

func _is_special_attack() -> bool:
	if _projectile == null or not is_instance_valid(_projectile):
		return false
	var special_value: Variant = _projectile.get("special_attack")
	return special_value != null and bool(special_value)

func emit_bounce() -> void:
	if not _bounce_visuals or _bounce_particles == null:
		return
	_bounce_particles.restart()
	_bounce_particles.emitting = true

func set_trail_enabled(enabled: bool) -> void:
	_trail_enabled = enabled
	if _trail:
		_trail.visible = enabled

func _setup_circle_body(base_color: Color, use_standard_style: bool = false) -> void:
	_is_standard = use_standard_style
	if _is_standard:
		_standard_visual = _create_standard_visual()
		if _standard_visual:
			_assign_canvas_layer(_standard_visual, 1)
			if _standard_visual.has_method("set_apply_color_callback"):
				_standard_visual.call("set_apply_color_callback", Callable(self, "_apply_color"))
			add_child(_standard_visual)
			if _standard_visual.has_method("configure"):
				_standard_visual.call("configure", base_color, _resolve_projectile_radius())
		return
	_sprite = Sprite2D.new()
	_sprite.texture = _white_texture
	var shader_material := ShaderMaterial.new()
	shader_material.shader = BULLET_SHADER
	shader_material.set_shader_parameter("fill_color", _apply_color(base_color))
	shader_material.set_shader_parameter("edge_softness", 0.18)
	shader_material.set_shader_parameter("intensity", 1.8)
	_sprite.material = shader_material
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_assign_canvas_layer(_sprite, 1)
	add_child(_sprite)

func _setup_weapon_visual(projectile: Node) -> bool:
	if projectile == null:
		return false
	var archetype_value: String = ""
	if projectile.has_method("get"):
		var variant: Variant = projectile.get("projectile_archetype")
		if variant is String:
			archetype_value = (variant as String).to_lower()
	if archetype_value.is_empty():
		return false
	var is_special: bool = false
	if projectile.has_method("get"):
		var special_variant: Variant = projectile.get("special_attack")
		if special_variant != null and typeof(special_variant) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
			is_special = bool(special_variant)
	var key: String = _resolve_weapon_visual_key(archetype_value, is_special)
	if key.is_empty():
		return false
	if not WeaponVisualScenePaths.has(key):
		return false
	var resource_path: String = WeaponVisualScenePaths.get(key, "")
	if resource_path.is_empty():
		return false
	var packed_resource := load(resource_path)
	if not (packed_resource is PackedScene):
		return false
	var packed_scene: PackedScene = packed_resource
	if _white_texture == null:
		_white_texture = _create_white_texture()
	var visual_instance: Node = packed_scene.instantiate()
	if not (visual_instance is Node2D):
		visual_instance.queue_free()
		return false
	_weapon_visual = visual_instance as Node2D
	_assign_canvas_layer(_weapon_visual, 1)
	if _weapon_visual.has_method("set_apply_color_callback"):
		_weapon_visual.call("set_apply_color_callback", Callable(self, "_apply_color"))
	if _weapon_visual.has_method("set_white_texture"):
		_weapon_visual.call("set_white_texture", _white_texture)
	add_child(_weapon_visual)
	var base_color: Color = Color(1.0, 1.0, 1.0, 1.0)
	if projectile.has_method("get"):
		var color_variant: Variant = projectile.get("color")
		if color_variant is Color:
			base_color = color_variant
	if _weapon_visual.has_method("configure_visual"):
		_weapon_visual.call("configure_visual", {
			"direction": Vector2.RIGHT,
			"radius": _resolve_projectile_radius(),
			"color": base_color,
			"context": {
				"special_attack": is_special,
				"archetype": archetype_value
			}
		})
	return true

func _resolve_weapon_visual_key(archetype: String, is_special: bool) -> String:
	var lower := archetype.to_lower()
	if is_special:
		var special_key := lower + "_special"
		if WeaponVisualScenePaths.has(special_key):
			return special_key
	if WeaponVisualScenePaths.has(lower):
		return lower
	return ""

func _collect_weapon_visual_context(has_bounced: bool) -> Dictionary:
	var context := {}
	context["has_bounced"] = has_bounced
	var special := false
	var archetype := ""
	var speed := 0.0
	if _projectile and is_instance_valid(_projectile) and _projectile.has_method("get"):
		var special_variant: Variant = _projectile.get("special_attack")
		if special_variant != null and typeof(special_variant) in [TYPE_BOOL, TYPE_FLOAT, TYPE_INT]:
			special = bool(special_variant)
		var archetype_variant: Variant = _projectile.get("projectile_archetype")
		if archetype_variant is String:
			archetype = (archetype_variant as String).to_lower()
		var speed_variant: Variant = _projectile.get("speed")
		if typeof(speed_variant) in [TYPE_FLOAT, TYPE_INT]:
			speed = float(speed_variant)
	context["special_attack"] = special
	context["archetype"] = archetype
	context["speed"] = speed
	return context

func _update_circle_colors(color: Color) -> void:
	if _is_standard and _standard_visual and _standard_visual.has_method("configure"):
		_standard_visual.call("configure", color, _resolve_projectile_radius())
		return
	if _sprite == null:
		return
	var circle_shader := _sprite.material
	if circle_shader == null:
		return
	circle_shader.set_shader_parameter("fill_color", _apply_color(color))
	circle_shader.set_shader_parameter("edge_softness", 0.18)

static func set_ambient_compensation(strength: float) -> void:
	_ambient_compensation_strength = clampf(strength, 1.0, 4.0)

static func set_time_of_day(is_day: bool) -> void:
	_is_day_time = is_day

static func set_vignette_profile(strength: float, inner_radius: float, softness: float, view_size: Vector2) -> void:
	_vignette_strength = clampf(strength, 0.0, 1.0)
	_vignette_inner_radius = clampf(inner_radius, 0.0, 1.5)
	_vignette_softness = clampf(softness, 0.0, 1.5)
	_vignette_view_size = view_size

static func _apply_compensation(color: Color, world_position: Vector2, viewport: Viewport) -> Color:
	var ambient_multiplier: float = clampf(_ambient_compensation_strength, 1.0, 4.0)
	var vignette_multiplier: float = 1.0
	var vignette_cap: float = _resolve_vignette_multiplier_cap()
	if _vignette_strength > 0.01 and viewport:
		var raw_vignette_multiplier: float = _compute_vignette_multiplier(world_position, viewport)
		vignette_multiplier = clampf(raw_vignette_multiplier, 1.0, vignette_cap)
	var total_multiplier: float = ambient_multiplier * vignette_multiplier
	var max_total_multiplier: float = ambient_multiplier * vignette_cap
	total_multiplier = clampf(total_multiplier, ambient_multiplier, max_total_multiplier)
	var compensated := Color(
		color.r * total_multiplier,
		color.g * total_multiplier,
		color.b * total_multiplier,
		color.a
	)
	var max_channel: float = maxf(maxf(compensated.r, compensated.g), compensated.b)
	if max_channel > 1.0:
		var normalize: float = 1.0 / max_channel
		compensated = Color(
			compensated.r * normalize,
			compensated.g * normalize,
			compensated.b * normalize,
			compensated.a
		)
	return compensated

static func _resolve_vignette_multiplier_cap() -> float:
	if _vignette_strength <= 0.01:
		return 1.0
	var capped_strength: float = clampf(_vignette_strength, 0.0, 0.92)
	return 1.0 / max(1.0 - capped_strength, 0.08)

static func _compute_vignette_multiplier(world_position: Vector2, viewport: Viewport) -> float:
	var camera: Camera2D = viewport.get_camera_2d()
	if camera == null:
		return 1.0
	var view_size: Vector2 = _resolve_view_size(viewport, camera)
	if view_size == Vector2.ZERO:
		return 1.0
	var local: Vector2 = camera.to_local(world_position)
	var uv: Vector2 = Vector2(
		0.5 + local.x / max(view_size.x, 1.0),
		0.5 + local.y / max(view_size.y, 1.0)
	)
	var centered: Vector2 = uv * 2.0 - Vector2.ONE
	var dist: float = centered.length()
	var edge: float = _smoothstep(_vignette_inner_radius, _vignette_inner_radius + _vignette_softness, dist)
	var alpha: float = clampf(edge * _vignette_strength, 0.0, 0.95)
	return 1.0 / max(1.0 - alpha, 0.35)

static func _resolve_view_size(viewport: Viewport, camera: Camera2D) -> Vector2:
	if _vignette_view_size != Vector2.ZERO:
		return _vignette_view_size
	var rect_size: Vector2 = viewport.get_visible_rect().size
	return Vector2(rect_size.x * camera.zoom.x, rect_size.y * camera.zoom.y)

static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var width: float = max(edge1 - edge0, 0.0001)
	var t: float = clampf((x - edge0) / width, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _apply_color(color: Color, offset: Vector2 = Vector2.ZERO) -> Color:
	var viewport: Viewport = get_viewport()
	var world_position: Vector2 = global_position + offset
	return _apply_compensation(color, world_position, viewport)

func _setup_tracer_body(color: Color) -> void:
	var compensated_color: Color = _apply_color(color)
	_tracer_body = Line2D.new()
	_tracer_body.width = 6.0
	_assign_canvas_layer(_tracer_body, 1)
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color(compensated_color.r, compensated_color.g, compensated_color.b, 0.0),
		Color(compensated_color.r, compensated_color.g, compensated_color.b, compensated_color.a),
		Color(compensated_color.r, compensated_color.g, compensated_color.b, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	_tracer_body.gradient = gradient
	_tracer_body.joint_mode = Line2D.LineJointMode.LINE_JOINT_ROUND
	_tracer_body.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	_tracer_body.end_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	add_child(_tracer_body)
	if _white_texture == null:
		_white_texture = _create_white_texture()
	_tracer_tip = Sprite2D.new()
	_tracer_tip.texture = _white_texture
	_tracer_tip.centered = true
	_assign_canvas_layer(_tracer_tip, 2)
	var tip_material: CanvasItemMaterial = CanvasItemMaterial.new()
	tip_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_tracer_tip.material = tip_material
	_tracer_tip.modulate = Color(compensated_color.r, compensated_color.g, compensated_color.b, clampf(compensated_color.a * 1.1, 0.0, 1.0))
	add_child(_tracer_tip)

func _update_tracer_body(direction: Vector2, radius: float, _color: Color) -> void:
	var compensated_color: Color = _apply_color(_color)
	var dir: Vector2 = direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var speed_scale: float = 1.0
	if _projectile and _projectile.has_method("get"):
		var speed_variant: Variant = _projectile.get("speed")
		if typeof(speed_variant) == TYPE_INT or typeof(speed_variant) == TYPE_FLOAT:
			var speed_value: float = float(speed_variant)
			if speed_value > 0.0:
				speed_scale = clampf(speed_value / 900.0, 0.8, 1.6)
	var length: float = max(radius * 2.6 * speed_scale, 14.0)
	var front: Vector2 = dir * (length * 0.5)
	var back: Vector2 = -dir * (length * 0.35)
	_tracer_body.points = PackedVector2Array([back, front])
	_tracer_body.width = max(1.8, radius * 0.65)
	if _tracer_body.gradient:
		var body_gradient: Gradient = _tracer_body.gradient
		body_gradient.colors = PackedColorArray([
			Color(compensated_color.r, compensated_color.g, compensated_color.b, 0.0),
			Color(compensated_color.r, compensated_color.g, compensated_color.b, compensated_color.a),
			Color(compensated_color.r, compensated_color.g, compensated_color.b, 0.0)
		])
	_tracer_body.rotation = 0.0
	if _tracer_tip:
		_tracer_tip.position = front
		var tip_scale: float = max(_tracer_body.width * 0.85, 3.0)
		_tracer_tip.scale = Vector2.ONE * (tip_scale * 0.25)
		_tracer_tip.rotation = dir.angle()
		var tip_world_offset: Vector2 = to_global(front) - global_position
		var tip_color: Color = _apply_color(_color, tip_world_offset)
		_tracer_tip.modulate = Color(tip_color.r, tip_color.g, tip_color.b, clampf(tip_color.a * 1.05, 0.0, 1.0))

func _setup_neon_body(color: Color) -> void:
	var compensated_color: Color = _apply_color(color)
	_neon_glow = Line2D.new()
	_neon_glow.joint_mode = Line2D.LineJointMode.LINE_JOINT_ROUND
	_neon_glow.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	_neon_glow.end_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	_assign_canvas_layer(_neon_glow, 1)
	add_child(_neon_glow)
	_neon_core = Line2D.new()
	_neon_core.joint_mode = Line2D.LineJointMode.LINE_JOINT_ROUND
	_neon_core.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	_neon_core.end_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	_assign_canvas_layer(_neon_core, 2)
	add_child(_neon_core)
	_neon_tip = Sprite2D.new()
	_neon_tip.texture = _white_texture
	_neon_tip.centered = true
	_neon_tip.modulate = Color(compensated_color.r, compensated_color.g, compensated_color.b, 0.9)
	_assign_canvas_layer(_neon_tip, 3)
	add_child(_neon_tip)


func _update_neon_body(direction: Vector2, radius: float, color: Color, has_bounced: bool) -> void:
	if _neon_glow == null or _neon_core == null or _neon_tip == null:
		return
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var size_multiplier := 1.5
	var length: float = max(radius * 16.0 * size_multiplier, 36.0 * size_multiplier)
	var width: float = max(radius * 3.5 * size_multiplier, 8.0 * size_multiplier)
	var half_length := length * 0.5
	var front := dir * half_length
	var back := -front
	var points := PackedVector2Array([back, front])
	_neon_glow.points = points
	_neon_core.points = points
	_neon_glow.width = width * 2.4
	_neon_core.width = width
	var base_color := color
	var glow_color := Color(0.0, 0.8, 1.0, 0.65)
	var core_color := Color(0.85, 1.0, 1.0, 0.95)
	if has_bounced:
		base_color = Color(1.0, 0.62, 0.18, 1.0)
		glow_color = Color(1.0, 0.5, 0.1, 0.7)
		core_color = Color(1.0, 0.85, 0.4, 0.95)
	var compensated_glow: Color = _apply_color(glow_color)
	var compensated_core: Color = _apply_color(Color(base_color.r, base_color.g, base_color.b, 1.0))
	_neon_glow.gradient = _build_neon_gradient(compensated_glow, 0.4)
	_neon_core.gradient = _build_neon_gradient(compensated_core, 0.1)
	_neon_tip.position = front
	var tip_scale: float = max(width * 0.6, 4.0 * size_multiplier)
	_neon_tip.scale = Vector2.ONE * (tip_scale * 0.5)
	var tip_offset := to_global(front) - global_position
	_neon_tip.modulate = _apply_color(core_color, tip_offset)
	_neon_tip.rotation = dir.angle()
	if _trail:
		_trail.visible = _trail_enabled

func _setup_laser_body(color: Color) -> void:
	var compensated_color: Color = _apply_color(color)
	_laser_layers.clear()
	_laser_crackles.clear()
	for _i in range(LASER_LAYER_COUNT):
		var layer := Polygon2D.new()
		layer.color = _apply_color(Color(1.0, 1.0, 1.0, 0.12))
		layer.antialiased = true
		_assign_canvas_layer(layer, 0)
		add_child(layer)
		_laser_layers.append(layer)
	_laser_core = Polygon2D.new()
	_laser_core.color = compensated_color
	_laser_core.antialiased = true
	_assign_canvas_layer(_laser_core, 1)
	add_child(_laser_core)
	_laser_center_line = Line2D.new()
	_laser_center_line.width = 4.0
	_laser_center_line.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	_laser_center_line.end_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	_assign_canvas_layer(_laser_center_line, 2)
	add_child(_laser_center_line)
	_laser_tip_glow = Sprite2D.new()
	_laser_tip_glow.texture = _white_texture
	_laser_tip_glow.centered = true
	_laser_tip_glow.modulate = _apply_color(Color(1.0, 1.0, 1.0, 0.85))
	_assign_canvas_layer(_laser_tip_glow, 3)
	add_child(_laser_tip_glow)
	_laser_tip_highlight = Sprite2D.new()
	_laser_tip_highlight.texture = _white_texture
	_laser_tip_highlight.centered = true
	_laser_tip_highlight.modulate = _apply_color(Color(0.96, 0.99, 1.0, 0.9))
	_assign_canvas_layer(_laser_tip_highlight, 4)
	add_child(_laser_tip_highlight)
	_laser_tip_particles = GPUParticles2D.new()
	_laser_tip_particles.amount = 36
	_laser_tip_particles.lifetime = 0.4
	_laser_tip_particles.one_shot = false
	_laser_tip_particles.preprocess = 0.2
	_laser_tip_particles.emitting = true
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 4.0
	particle_material.direction = Vector3.ZERO
	particle_material.spread = 45.0
	particle_material.initial_velocity_min = 140.0
	particle_material.initial_velocity_max = 220.0
	particle_material.scale_min = 0.5
	particle_material.scale_max = 0.9
	particle_material.gravity = Vector3.ZERO
	particle_material.damping_min = 4.0
	particle_material.damping_max = 6.0
	particle_material.angle_min = -30.0
	particle_material.angle_max = 30.0
	particle_material.angular_velocity_min = -18.0
	particle_material.angular_velocity_max = 18.0
	particle_material.color = compensated_color
	_laser_tip_particles.process_material = particle_material
	_assign_canvas_layer(_laser_tip_particles, 3)
	add_child(_laser_tip_particles)
	for _i in range(LASER_CRACKLE_COUNT):
		var crackle := Line2D.new()
		crackle.width = 1.2
		crackle.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
		crackle.end_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
		_assign_canvas_layer(crackle, 1)
		add_child(crackle)
		_laser_crackles.append(crackle)

func _update_laser_body(direction: Vector2, radius: float, color: Color) -> void:
	if _laser_layers.is_empty() or _laser_core == null or _laser_center_line == null:
		return
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var is_special := _is_special_attack()
	var length_multiplier := 120.0 if is_special else 115.0
	var min_length := 360.0 if is_special else 420.0
	var beam_length: float = max(radius * length_multiplier, min_length)
	var beam_width: float = max(radius * 4.0, 10.0)
	if is_special:
		beam_width = max(radius * 6.0, 14.0)
	var neck_factor := 0.16
	var neck_max := 48.0
	var tip_factor := 0.12
	var tip_max := 48.0
	if not is_special:
		neck_factor = 0.1
		neck_max = 64.0
		tip_factor = 0.08
		tip_max = 72.0
	var neck_back: float = clampf(beam_length * neck_factor, 12.0, neck_max)
	var tip_length: float = clampf(beam_length * tip_factor, 18.0, tip_max)
	var layer_widths: Array = [beam_width * 3.0, beam_width * 2.0, beam_width * 1.3]
	var layer_colors: Array = _resolve_laser_layer_colors(color, is_special)
	var front: Vector2 = dir * beam_length
	var beam_center_offset: Vector2 = to_global(front * 0.5) - global_position
	var compensated_color: Color = _apply_color(color, beam_center_offset)
	for i in range(_laser_layers.size()):
		var layer_node: Polygon2D = _laser_layers[i]
		layer_node.polygon = _build_diamond_polygon(front, dir, layer_widths[i], neck_back, tip_length)
		layer_node.color = _apply_color(layer_colors[i], beam_center_offset)
	_laser_core.polygon = _build_diamond_polygon(front, dir, beam_width, neck_back, tip_length * 0.85)
	_laser_core.color = compensated_color
	_laser_center_line.points = PackedVector2Array([Vector2.ZERO, front])
	_laser_center_line.width = max(beam_width * 0.22, 2.0)
	if _laser_center_line.gradient == null:
		var line_gradient := Gradient.new()
		line_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		_laser_center_line.gradient = line_gradient
	var center_gradient := _laser_center_line.gradient
	if center_gradient:
		center_gradient.colors = PackedColorArray([
			_apply_color(Color(1.0, 1.0, 1.0, 0.15), beam_center_offset),
			_apply_color(Color(1.0, 1.0, 1.0, 1.0), beam_center_offset),
			_apply_color(Color(1.0, 1.0, 1.0, 0.2), beam_center_offset)
		])
	var tip_scale: float = max(beam_width * 0.14, 1.6)
	_laser_tip_glow.position = front
	_laser_tip_glow.scale = Vector2.ONE * tip_scale
	var tip_glow_color := Color(min(color.r + 0.4, 1.0), min(color.g + 0.4, 1.0), min(color.b + 0.4, 1.0), 0.9)
	var tip_world_offset := to_global(front) - global_position
	_laser_tip_glow.modulate = _apply_color(tip_glow_color, tip_world_offset)
	_laser_tip_highlight.position = front - dir * tip_length * 0.25
	_laser_tip_highlight.scale = Vector2.ONE * (tip_scale * 0.6)
	var highlight_local := front - dir * tip_length * 0.25
	var highlight_offset := to_global(highlight_local) - global_position
	_laser_tip_highlight.modulate = _apply_color(Color(0.96, 0.99, 1.0, 0.65), highlight_offset)
	if _laser_tip_particles and _laser_tip_particles.process_material is ParticleProcessMaterial:
		var particle_process_material := _laser_tip_particles.process_material as ParticleProcessMaterial
		particle_process_material.direction = Vector3(-dir.x, -dir.y, 0.0)
		particle_process_material.color = compensated_color
		_laser_tip_particles.position = front
		_laser_tip_particles.rotation = dir.angle()
	_update_laser_crackles(dir, beam_length, beam_width)
	_update_glow_position_for_laser(dir, beam_length, beam_width)

func _build_diamond_polygon(front: Vector2, dir: Vector2, width: float, neck_back: float, tip_length: float) -> PackedVector2Array:
	var neck_position: float = max(neck_back, 8.0)
	var tip_extent: float = max(tip_length, 6.0)
	var ortho: Vector2 = dir.orthogonal() * (width * 0.5)
	var neck_forward: Vector2 = dir * neck_position
	var near_tip: Vector2 = front - dir * tip_extent
	var tip_ortho := dir.orthogonal() * (width * 0.38)
	return PackedVector2Array([
		Vector2.ZERO,
		neck_forward + ortho,
		near_tip + tip_ortho,
		front,
		near_tip - tip_ortho,
		neck_forward - ortho
	])

func _resolve_laser_layer_colors(base_color: Color, is_special: bool) -> Array:
	var outer: Color
	var mid: Color
	var inner: Color
	if is_special:
		outer = _offset_color(base_color, -0.25, -0.15, -0.1, 0.45)
		mid = _offset_color(base_color, 0.05, 0.05, 0.08, 0.68)
		inner = _offset_color(base_color, 0.22, 0.2, 0.18, 0.82)
	else:
		outer = _offset_color(base_color, -0.45, -0.3, -0.3, 0.18)
		mid = _offset_color(base_color, -0.25, 0.0, 0.0, 0.32)
		inner = _offset_color(base_color, 0.0, 0.0, 0.0, 0.45)
	return [outer, mid, inner]

func _offset_color(base: Color, r_offset: float, g_offset: float, b_offset: float, alpha: float) -> Color:
	return Color(
		clampf(base.r + r_offset, 0.0, 1.0),
		clampf(base.g + g_offset, 0.0, 1.0),
		clampf(base.b + b_offset, 0.0, 1.0),
		clampf(alpha, 0.0, 1.0)
	)

func _update_laser_crackles(dir: Vector2, length: float, beam_width: float) -> void:
	if _laser_crackles.is_empty():
		return
	var count: int = _laser_crackles.size()
	for i in range(count):
		var t: float = float(i + 1) / float(count + 1)
		var base: Vector2 = dir * length * t
		var offset_distance: float = _laser_rng.randf_range(beam_width * 0.45, beam_width * 1.35)
		var angle: float = _laser_rng.randf_range(0.0, TAU)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * offset_distance
		var crackle: Line2D = _laser_crackles[i]
		crackle.points = PackedVector2Array([base, base + offset])
		var color_choice := _laser_rng.randf() > 0.45
		var crackle_color := Color(0.78, 0.9, 1.0, 0.9) if color_choice else Color(1.0, 1.0, 1.0, 0.9)
		var sample_local := base + offset * 0.5
		var sample_world_offset := to_global(sample_local) - global_position
		crackle.default_color = _apply_color(crackle_color, sample_world_offset)

func _setup_trail(shape: String, trail_color: Color) -> void:
	_trail = Line2D.new()
	_assign_canvas_layer(_trail, 0)
	var gradient := Gradient.new()
	match shape:
		"pellet":
			_trail.width = 10.0
			gradient.colors = PackedColorArray([
				_apply_color(Color(1.0, 0.55, 0.25, 0.0)),
				_apply_color(Color(1.0, 0.45, 0.15, 0.8))
			])
		"tracer":
			_trail.width = 7.0
			gradient.colors = PackedColorArray([
				_apply_color(Color(1.0, 0.6, 0.2, 0.0)),
				_apply_color(Color(1.0, 0.7, 0.2, 0.9))
			])
		"neon":
			_trail.width = 4.0
			gradient.colors = PackedColorArray([
				_apply_color(Color(0.0, 0.9, 1.0, 0.0)),
				_apply_color(Color(0.0, 0.85, 1.0, 0.425))
			])
		_:
			_trail.width = 6.0
			gradient.colors = PackedColorArray([
				_apply_color(Color(trail_color.r, trail_color.g, trail_color.b, 0.0)),
				_apply_color(Color(trail_color.r, trail_color.g, trail_color.b, max(trail_color.a, 0.75)))
			])
	_trail.gradient = gradient
	_trail.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
	_trail.visible = false
	add_child(_trail)

func _update_trail(points: Array) -> void:
	if not _trail_enabled:
		_trail.points = PackedVector2Array()
		return
	_trail_point_cache = PackedVector2Array()
	for point in points:
		var local := to_local(point)
		_trail_point_cache.append(local)
	_trail.points = _trail_point_cache

func _setup_bounce_particles(color: Color) -> void:
	_bounce_particles = GPUParticles2D.new()
	_bounce_particles.one_shot = true
	_bounce_particles.amount = 12
	_bounce_particles.lifetime = 0.3
	_bounce_particles.preprocess = 0.0
	_bounce_particles.emitting = false
	var particles_material := ParticleProcessMaterial.new()
	particles_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particles_material.emission_sphere_radius = 2.0
	particles_material.initial_velocity_min = 80.0
	particles_material.initial_velocity_max = 150.0
	particles_material.gravity = Vector3.ZERO
	particles_material.damping_min = 10.0
	particles_material.damping_max = 20.0
	particles_material.scale_min = 0.4
	particles_material.scale_max = 0.8
	particles_material.angle_min = 0.0
	particles_material.angle_max = 360.0
	particles_material.color = _apply_color(color)
	_bounce_particles.process_material = particles_material
	_assign_canvas_layer(_bounce_particles, 1)
	add_child(_bounce_particles)

func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_sprite = null
	_trail = null
	_tracer_body = null
	_tracer_tip = null
	_neon_glow = null
	_neon_core = null
	_neon_tip = null
	_laser_layers.clear()
	_laser_core = null
	_laser_center_line = null
	_laser_tip_glow = null
	_laser_tip_highlight = null
	_laser_tip_particles = null
	_laser_crackles.clear()
	_bounce_particles = null
	_glow_sprite = null
	_is_tracer = false
	_is_neon = false
	_is_laser = false
	_is_pellet = false
	_is_standard = false
	_standard_visual = null
	_is_minigun = false
	_trail_enabled = false
	_glow_enabled = false
	_glow_color = Color(1.0, 1.0, 1.0, 1.0)
	_glow_energy = 1.0
	_glow_scale = 1.0
	_glow_height = 0.0
	_weapon_visual = null


func _setup_editor_preview() -> void:
	_clear_children()
	var preview_color := Color(1.0, 0.88, 0.3, 1.0)
	_setup_circle_body(preview_color, true)
	_ensure_glow_sprite()
	configure_glow(true, Color(1.0, 0.78, 0.35, 0.7), 1.1, 1.0, 0.0)
	if _standard_visual and _standard_visual.has_method("configure"):
		_standard_visual.call("configure", preview_color, 6.0)


func _create_standard_visual() -> Node2D:
	if StandardBulletVisualScene:
		var instance: Node = StandardBulletVisualScene.instantiate()
		if instance is Node2D:
			return instance as Node2D
		instance.queue_free()
	if StandardBulletVisualScript:
		var fallback: Node = StandardBulletVisualScript.new()
		if fallback is Node2D:
			return fallback
	return null

func _resolve_projectile_radius() -> float:
	if _projectile == null:
		return 4.0
	if _projectile.has_method("get"):
		var variant: Variant = _projectile.get("radius")
		if typeof(variant) == TYPE_INT or typeof(variant) == TYPE_FLOAT:
			return max(0.5, float(variant))
	return 4.0


func _create_white_texture() -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)

func _create_radial_glow_texture(size: int = 96) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_radius: float = min(center.x, center.y)
	for y in size:
		for x in size:
			var pos := Vector2(x + 0.5, y + 0.5)
			var distance := pos.distance_to(center)
			var normalized: float = distance / max_radius
			var alpha: float = 0.0
			if normalized < 1.0:
				var falloff := pow(1.0 - normalized, 2.4)
				alpha = clampf(falloff, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)

func _build_neon_gradient(color: Color, fade_strength: float) -> Gradient:
	var gradient := Gradient.new()
	var transparent := Color(color.r, color.g, color.b, max(0.0, color.a - fade_strength))
	gradient.colors = PackedColorArray([
		Color(transparent.r, transparent.g, transparent.b, 0.0),
		color,
		Color(transparent.r, transparent.g, transparent.b, 0.0)
	])
	return gradient

func configure_glow(enabled: bool, glow_color: Color, glow_energy: float, glow_scale: float, glow_height: float) -> void:
	_glow_enabled = enabled
	_glow_color = glow_color
	_glow_energy = glow_energy
	_glow_scale = glow_scale
	_glow_height = glow_height
	_ensure_glow_sprite()
	_update_glow_state()

func _ensure_glow_sprite() -> void:
	if _glow_sprite:
		return
	if _glow_texture == null:
		_glow_texture = _create_radial_glow_texture()
	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = _glow_texture
	_glow_sprite.centered = true
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_sprite.material = glow_material
	_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow_sprite.visible = false
	_assign_canvas_layer(_glow_sprite, 2)
	add_child(_glow_sprite)

func _update_glow_state() -> void:
	if _glow_sprite == null:
		return
	_glow_sprite.visible = _glow_enabled
	if not _glow_enabled:
		return
	var energized_alpha := clampf(_glow_color.a * max(_glow_energy, 0.0), 0.0, 1.0)
	var compensated: Color = _apply_color(Color(_glow_color.r, _glow_color.g, _glow_color.b, 1.0), Vector2(0.0, -_glow_height))
	_glow_sprite.modulate = Color(compensated.r, compensated.g, compensated.b, energized_alpha)

func _update_glow_visual(direction: Vector2, radius: float) -> void:
	if _glow_sprite == null:
		return
	_update_glow_state()
	if not _glow_enabled:
		return
	if _is_laser:
		var dir := direction.normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var is_special := _is_special_attack()
		var length_multiplier := 120.0 if is_special else 115.0
		var min_length := 360.0 if is_special else 420.0
		var beam_length: float = max(radius * length_multiplier, min_length)
		_update_glow_position_for_laser(dir, beam_length, max(radius * 4.0, 10.0))
	else:
		var base_radius: float = max(radius * 1.6, 6.0)
		var offset := Vector2(0.0, -_glow_height)
		if _is_tracer or _is_minigun:
			var dir := direction.normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var length_scale := maxf(_glow_scale * base_radius * 0.12, 0.12)
			var width_scale := maxf(_glow_scale * base_radius * 0.05, 0.06)
			_glow_sprite.scale = Vector2(width_scale, length_scale)
			_glow_sprite.rotation = dir.angle()
			_glow_sprite.position = offset + dir * (base_radius * 0.18)
		else:
			var uniform_scale := maxf(_glow_scale * base_radius * 0.1, 0.05)
			_glow_sprite.scale = Vector2.ONE * uniform_scale
			_glow_sprite.rotation = 0.0
			_glow_sprite.position = offset

func _update_glow_position_for_laser(dir: Vector2, beam_length: float, beam_width: float) -> void:
	if _glow_sprite == null or not _glow_enabled:
		return
	_glow_sprite.position = dir * (beam_length + _glow_height)
	var width_factor: float = max(beam_width * 0.085, 1.6)
	var length_factor: float = max(beam_length * 0.0032, 0.12)
	var scale_value: float = max(_glow_scale * (width_factor + length_factor), 0.12)
	_glow_sprite.scale = Vector2.ONE * scale_value
	_glow_sprite.rotation = dir.angle()
