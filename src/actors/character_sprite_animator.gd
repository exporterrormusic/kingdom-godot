extends AnimatedSprite2D
class_name CharacterSpriteAnimator

const DEFAULT_COLUMNS := 3
const DEFAULT_ROWS := 4
const MAX_FRAMES_PER_ANIMATION := 3
const DIRECTION_ROWS := {
	"down": 0,
	"left": 1,
	"right": 2,
	"up": 3,
}
const TARGET_MAX_HEIGHT := 320.0
const TARGET_MAX_WIDTH := 260.0
const MIN_SCALE := 0.08
const MAX_SCALE := 4.0
const DEFAULT_SCALE := 0.2
const MOVEMENT_THRESHOLD := 8.0
const AIM_THRESHOLD := 0.25

var _has_sprite := false
var _last_direction: StringName = "down"
var _base_animation_fps := 6.0
var _scale_factor: float = DEFAULT_SCALE

func _ready() -> void:
	visible = false
	stop()
	centered = true
	z_index = 10

func configure_from_character(character: CharacterData) -> void:
	if character == null:
		clear()
		return
	var scale_value: float = character.sprite_scale if character.sprite_scale > 0.0 else DEFAULT_SCALE
	configure(character.sprite_sheet, character.sprite_sheet_columns, character.sprite_sheet_rows, character.sprite_animation_fps, scale_value)

func configure(sprite_sheet: Texture2D, columns: int, rows: int, fps: float, scale_factor: float = DEFAULT_SCALE) -> void:
	if sprite_sheet == null:
		clear()
		return

	_scale_factor = clamp(scale_factor, MIN_SCALE, MAX_SCALE)

	columns = _normalize_axis(columns, DEFAULT_COLUMNS)
	rows = _normalize_axis(rows, DEFAULT_ROWS)

	var texture_size: Vector2 = sprite_sheet.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		clear()
		return

	var frame_width := int(round(texture_size.x / float(columns)))
	var frame_height := int(round(texture_size.y / float(rows)))
	if frame_width <= 0 or frame_height <= 0:
		clear()
		return

	var frames := SpriteFrames.new()
	var added_any := false
	var frames_per_direction: int = min(MAX_FRAMES_PER_ANIMATION, columns)
	var animation_fps: float = max(fps, 0.1)

	for direction in DIRECTION_ROWS.keys():
		var row_index: int = DIRECTION_ROWS[direction]
		if row_index >= rows:
			continue
		frames.add_animation(direction)
		frames.set_animation_loop(direction, true)
		frames.set_animation_speed(direction, animation_fps)
		for col in range(frames_per_direction):
			var region := Rect2i(col * frame_width, row_index * frame_height, frame_width, frame_height)
			var atlas := AtlasTexture.new()
			atlas.atlas = sprite_sheet
			atlas.region = region
			frames.add_frame(direction, atlas)
		added_any = added_any or frames.get_frame_count(direction) > 0

	if not added_any:
		clear()
		return

	sprite_frames = frames
	animation = "down" if frames.has_animation("down") else frames.get_animation_names()[0]
	frame = 0
	stop()
	speed_scale = 1.0
	_last_direction = animation
	_base_animation_fps = animation_fps
	_has_sprite = true
	visible = true
	_update_scale(frame_width, frame_height)

func clear() -> void:
	_has_sprite = false
	stop()
	frame = 0
	visible = false
	sprite_frames = null
	_last_direction = "down"
	_scale_factor = DEFAULT_SCALE

func update_state(move_velocity: Vector2, aim_vector: Vector2) -> void:
	if not _has_sprite or sprite_frames == null:
		return

	var is_moving := move_velocity.length() >= MOVEMENT_THRESHOLD
	var movement_direction := _direction_from_vector(move_velocity)
	var has_aim := aim_vector.length() >= AIM_THRESHOLD
	var facing_direction := ""

	if has_aim:
		facing_direction = _direction_from_vector(aim_vector)
	if facing_direction == "":
		facing_direction = movement_direction
	if facing_direction == "":
		facing_direction = _last_direction

	var reverse := false
	if is_moving and movement_direction != "":
		if movement_direction == facing_direction:
			reverse = false
		elif movement_direction == _opposite_direction(facing_direction):
			reverse = true
		else:
			facing_direction = movement_direction

	if is_moving:
		_play_walk_animation(facing_direction, reverse)
	else:
		_show_idle_frame(facing_direction)

func _play_walk_animation(direction: String, reverse: bool) -> void:
	if not sprite_frames or not sprite_frames.has_animation(direction):
		return
	var changed_animation := animation != direction
	if changed_animation:
		animation = direction
	if reverse:
		speed_scale = -1.0
		if not is_playing() or frame == 0:
			frame = sprite_frames.get_frame_count(direction) - 1
	else:
		speed_scale = 1.0
		if speed_scale < 0:
			frame = sprite_frames.get_frame_count(direction) - 1 - frame
			speed_scale = 1.0

	if changed_animation or not is_playing():
		play(direction)
	_last_direction = direction

func _show_idle_frame(direction: String) -> void:
	if not sprite_frames or not sprite_frames.has_animation(direction):
		return
	animation = direction
	speed_scale = 1.0
	frame = 0
	stop()
	_last_direction = direction

func _normalize_axis(value: int, fallback: int) -> int:
	return fallback if value <= 0 else value

func _direction_from_vector(vec: Vector2) -> String:
	if abs(vec.x) < 0.01 and abs(vec.y) < 0.01:
		return ""
	if abs(vec.x) > abs(vec.y):
		return "right" if vec.x > 0.0 else "left"
	else:
		return "down" if vec.y > 0.0 else "up"

func _opposite_direction(direction: String) -> String:
	match direction:
		"up":
			return "down"
		"down":
			return "up"
		"left":
			return "right"
		"right":
			return "left"
		_:
			return ""

func _update_scale(frame_width: int, frame_height: int) -> void:
	if frame_width <= 0 or frame_height <= 0:
		scale = Vector2.ONE
		return
	var auto_width_scale: float = TARGET_MAX_WIDTH / max(1.0, float(frame_width))
	var auto_height_scale: float = TARGET_MAX_HEIGHT / max(1.0, float(frame_height))
	var auto_scale: float = min(auto_width_scale, auto_height_scale)
	var factor: float = clamp(min(auto_scale, _scale_factor), MIN_SCALE, MAX_SCALE)
	scale = Vector2.ONE * factor
