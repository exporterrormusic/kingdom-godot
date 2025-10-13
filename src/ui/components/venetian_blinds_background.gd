extends Control
class_name VenetianBlindsBackground

@export var background_textures: PackedStringArray = []
@export var blind_base_width: float = 540.0
@export var blind_angle_degrees: float = 15.0
@export var carousel_speed: float = 100.0
@export var overlay_color: Color = Color(0, 0, 0, 0.24)

const DEFAULT_BACKGROUNDS := [
	"res://assets/images/Menu/BKG/ark.jpg",
	"res://assets/images/Menu/BKG/battlefield1.jpg",
	"res://assets/images/Menu/BKG/eden.jpg",
	"res://assets/images/Menu/BKG/forest.jpg",
	"res://assets/images/Menu/BKG/hg.jpg",
	"res://assets/images/Menu/BKG/kingdom.jpg",
	"res://assets/images/Menu/BKG/mushroom.jpg",
	"res://assets/images/Menu/BKG/rapturefield1.jpg",
	"res://assets/images/Menu/BKG/rapturefield2.jpg",
	"res://assets/images/Menu/BKG/space.jpg"
]

const MENU_BACKGROUND_DIR := "res://assets/images/Menu/BKG"
const CHARACTER_ROOT_DIR := "res://assets/images/Characters"
const SUPPORTED_EXTENSIONS := [".png", ".jpg", ".jpeg", ".webp"]

static var _prepared_cache: Dictionary = {}
static var _default_texture_paths_cache: PackedStringArray = PackedStringArray()

var _textures: Array[Texture2D] = []
var _prepared_textures: Array[Dictionary] = []
var _animation_offset: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_load_textures()
	_prepare_textures()
	_queue_full_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_prepare_textures()
		_queue_full_redraw()

func _process(delta: float) -> void:
	var textures = _get_active_textures()
	if textures.is_empty():
		return
	var total_width = _get_blind_width() * textures.size()
	if total_width <= 0.0:
		return
	_animation_offset = fposmod(_animation_offset + carousel_speed * delta, total_width)
	queue_redraw()

func _draw() -> void:
	var textures = _get_active_textures()
	if textures.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12))
		draw_rect(Rect2(Vector2.ZERO, size), overlay_color)
		return

	var blind_width = _get_blind_width()
	var angle_offset = size.y * tan(deg_to_rad(blind_angle_degrees))
	var total_width = blind_width * textures.size()
	if total_width <= 0.0:
		return

	var start_index = int(_animation_offset / blind_width) - 1
	var blinds_needed = int(ceil((size.x + abs(angle_offset) + blind_width) / blind_width)) + 3

	for i in range(blinds_needed):
		var blind_x = (start_index + i) * blind_width - _animation_offset
		var texture_index = posmod(start_index + i, textures.size())
		var texture_entry = textures[texture_index]
		_draw_blind(texture_entry, blind_x, blind_width, angle_offset)

	draw_rect(Rect2(Vector2.ZERO, size), overlay_color)

func set_background_textures(paths: PackedStringArray) -> void:
	background_textures = paths
	_load_textures()
	_prepare_textures()
	queue_redraw()

func _load_textures() -> void:
	_textures.clear()
	var texture_paths = background_textures
	if texture_paths.is_empty():
		texture_paths = _build_default_texture_paths()
	if texture_paths.is_empty():
		texture_paths = PackedStringArray(DEFAULT_BACKGROUNDS)
	background_textures = texture_paths
	for path in texture_paths:
		var texture = load(path)
		if texture is Texture2D:
			_textures.append(texture)
		else:
			push_warning("Failed to load background texture: %s" % path)
	_prepare_textures()

func _draw_blind(texture_entry: Dictionary, start_x: float, blind_width: float, angle_offset: float) -> void:
	var texture: Texture2D = texture_entry.get("texture", null)
	if not texture:
		return
	var uvs = PackedVector2Array([
		texture_entry.get("uv_top_left", Vector2(0.0, 0.0)),
		texture_entry.get("uv_top_right", Vector2(1.0, 0.0)),
		texture_entry.get("uv_bottom_right", Vector2(1.0, 1.0)),
		texture_entry.get("uv_bottom_left", Vector2(0.0, 1.0))
	])

	var points = PackedVector2Array([
		Vector2(start_x, 0.0),
		Vector2(start_x + blind_width, 0.0),
		Vector2(start_x + blind_width + angle_offset, size.y),
		Vector2(start_x + angle_offset, size.y)
	])

	var color = Color.WHITE
	var colors = PackedColorArray([color, color, color, color])

	draw_polygon(points, colors, uvs, texture)
	_draw_blind_edges(points)

func _draw_blind_edges(points: PackedVector2Array) -> void:
	if points.size() < 4:
		return
	var edge_color = Color(1, 1, 1, 0.24)
	var thickness = 3.0
	draw_line(points[0], points[3], edge_color, thickness)
	draw_line(points[1], points[2], edge_color, thickness)

func _get_blind_width() -> float:
	if size.y <= 0.0:
		return blind_base_width
	var scale_factor = size.y / 1080.0
	return blind_base_width * max(scale_factor, 0.25)

func _queue_full_redraw() -> void:
	_animation_offset = 0.0
	queue_redraw()


func _get_active_textures() -> Array:
	if not _prepared_textures.is_empty():
		return _prepared_textures
	if _textures.is_empty():
		return []
	var entries: Array = []
	for texture in _textures:
		if texture:
			entries.append({
				"texture": texture,
				"uv_top_left": Vector2(0.0, 0.0),
				"uv_top_right": Vector2(1.0, 0.0),
				"uv_bottom_right": Vector2(1.0, 1.0),
				"uv_bottom_left": Vector2(0.0, 1.0)
			})
	return entries

func _prepare_textures() -> void:
	_prepared_textures.clear()
	if size.y <= 0.0:
		return
	if _textures.is_empty():
		return
	var blind_width = int(round(_get_blind_width()))
	var angle_offset: int = int(round(abs(size.y * tan(deg_to_rad(blind_angle_degrees)))))
	var target_height = int(round(max(size.y, 1.0)))
	if blind_width <= 0 or target_height <= 0:
		return
	for original in _textures:
		var prepared = _create_prepared_texture(original, blind_width, angle_offset, target_height)
		if not prepared.is_empty():
			_prepared_textures.append(prepared)

func _create_prepared_texture(original: Texture2D, blind_width: int, angle_offset: int, target_height: int) -> Dictionary:
	if original == null:
		return {}
	var cache_key: String = _build_cache_key(original, blind_width, angle_offset, target_height)
	if _prepared_cache.has(cache_key):
		return _prepared_cache[cache_key]
	var source_image = original.get_image()
	if source_image == null or source_image.is_empty():
		var fallback: Dictionary = _make_texture_entry(original)
		_prepared_cache[cache_key] = fallback
		return fallback
	var image = source_image.duplicate()
	if image.is_compressed():
		var decompress_error: Error = image.decompress()
		if decompress_error != OK:
			push_warning("Failed to decompress texture for venetian blinds: %s" % original.resource_path)
			var fallback_decompress: Dictionary = _make_texture_entry(original)
			_prepared_cache[cache_key] = fallback_decompress
			return fallback_decompress
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var original_size: Vector2i = image.get_size()
	if original_size.x <= 0 or original_size.y <= 0:
		var fallback_empty: Dictionary = _make_texture_entry(original)
		_prepared_cache[cache_key] = fallback_empty
		return fallback_empty
	var effective_width: int = max(1, blind_width + abs(angle_offset))
	var target_width: int = effective_width
	var scale_x: float = float(effective_width) / float(original_size.x)
	var scale_y: float = float(target_height) / float(original_size.y)
	var scale_factor: float = max(scale_x, scale_y)
	if scale_factor <= 0.0:
		scale_factor = 1.0
	var scaled_width: int = max(1, int(round(original_size.x * scale_factor)))
	var scaled_height: int = max(1, int(round(original_size.y * scale_factor)))
	image.resize(scaled_width, scaled_height, Image.INTERPOLATE_LANCZOS)
	var final_image = Image.create(target_width, target_height, false, image.get_format())
	final_image.fill(Color(0, 0, 0, 0))
	var dest_pos = Vector2i(int(round((target_width - scaled_width) / 2.0)), int(round((target_height - scaled_height) / 2.0)))
	_blit_image_with_clipping(final_image, image, dest_pos)
	var safe_width: int = max(target_width, 1)
	var top_left_u: float = 0.0
	var top_right_u: float = float(blind_width) / float(safe_width)
	var bottom_left_u: float = float(angle_offset) / float(safe_width)
	var bottom_right_u: float = float(angle_offset + blind_width) / float(safe_width)
	var prepared_texture = ImageTexture.create_from_image(final_image)
	var entry: Dictionary = {
		"texture": prepared_texture,
		"uv_top_left": Vector2(top_left_u, 0.0),
		"uv_top_right": Vector2(top_right_u, 0.0),
		"uv_bottom_right": Vector2(bottom_right_u, 1.0),
		"uv_bottom_left": Vector2(bottom_left_u, 1.0)
	}
	_prepared_cache[cache_key] = entry
	return entry

static func _blit_image_with_clipping(dest: Image, src: Image, dest_pos: Vector2i) -> void:
	if dest == null or src == null:
		return
	var dest_size: Vector2i = dest.get_size()
	var src_size: Vector2i = src.get_size()
	if dest_size.x <= 0 or dest_size.y <= 0:
		return
	if src_size.x <= 0 or src_size.y <= 0:
		return
	for row in src_size.y:
		var dest_y: int = dest_pos.y + row
		if dest_y < 0 or dest_y >= dest_size.y:
			continue
		var dest_x: int = dest_pos.x
		var src_x: int = 0
		var remaining: int = src_size.x
		if dest_x < 0:
			var shift: int = min(-dest_x, remaining)
			dest_x += shift
			src_x += shift
			remaining -= shift
		if remaining <= 0:
			continue
		if dest_x >= dest_size.x:
			continue
		var max_copy: int = min(remaining, dest_size.x - dest_x)
		if max_copy <= 0:
			continue
		dest.blit_rect(src, Rect2i(Vector2i(src_x, row), Vector2i(max_copy, 1)), Vector2i(dest_x, dest_y))

static func _make_texture_entry(texture: Texture2D) -> Dictionary:
	return {
		"texture": texture,
		"uv_top_left": Vector2(0.0, 0.0),
		"uv_top_right": Vector2(1.0, 0.0),
		"uv_bottom_right": Vector2(1.0, 1.0),
		"uv_bottom_left": Vector2(0.0, 1.0)
	}

static func _build_cache_key(texture: Texture2D, blind_width: int, angle_offset: int, target_height: int) -> String:
	var identifier = texture.resource_path
	if identifier == "":
		identifier = str(texture.get_rid())
	var tex_size = texture.get_size()
	return "%s_%d_%d_%d_%d_%d" % [identifier, blind_width, angle_offset, target_height, int(tex_size.x), int(tex_size.y)]

func _build_default_texture_paths() -> PackedStringArray:
	if not _default_texture_paths_cache.is_empty():
		return _default_texture_paths_cache.duplicate()
	var backgrounds = _get_sorted_files_in_dir(MENU_BACKGROUND_DIR)
	var burst_paths = _get_character_burst_paths()
	if backgrounds.is_empty() and burst_paths.is_empty():
		return PackedStringArray()
	var combined = PackedStringArray()
	var max_count: int = max(backgrounds.size(), burst_paths.size())
	if max_count == 0:
		return combined
	for i in max_count:
		if backgrounds.size() > 0:
			combined.append(backgrounds[i % backgrounds.size()])
		if burst_paths.size() > 0:
			combined.append(burst_paths[i % burst_paths.size()])
	_default_texture_paths_cache = combined.duplicate()
	return combined

func _get_sorted_files_in_dir(path: String) -> PackedStringArray:
	var results = PackedStringArray()
	var dir = DirAccess.open(path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			var lower = entry.to_lower()
			for ext in SUPPORTED_EXTENSIONS:
				if lower.ends_with(ext):
					results.append("%s/%s" % [path, entry])
					break
		entry = dir.get_next()
	dir.list_dir_end()
	results.sort()
	return results

func _get_character_burst_paths() -> PackedStringArray:
	var results = PackedStringArray()
	var dir = DirAccess.open(CHARACTER_ROOT_DIR)
	if dir == null:
		return results
	var folders = []
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			folders.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	folders.sort()
	for folder_name in folders:
		var burst_path = "%s/%s/burst.png" % [CHARACTER_ROOT_DIR, folder_name]
		if ResourceLoader.exists(burst_path):
			results.append(burst_path)
	return results
