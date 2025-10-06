extends Control
class_name CharacterCard

signal pressed(card: CharacterCard)
signal hovered(card: CharacterCard)

@export var hover_scale: float = 1.05
@export var animation_speed: float = 0.16

var code_name: String = ""
var is_random: bool = false
var character_reference: CharacterData = null

@onready var _background: ColorRect = %Background
@onready var _burst_frame: Panel = %BurstFrame
@onready var _image: TextureRect = %BurstTexture
@onready var _name_label: Label = %NameLabel
@onready var _question_label: Label = %QuestionLabel

var _selected: bool = false
var _tween: Tween = null
var _border_color: Color = Color(0.39, 0.39, 0.47, 1.0)

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	scale = Vector2.ONE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func configure(name_text: String, texture: Texture2D, is_random_card: bool, ref: CharacterData) -> void:
	code_name = ref.code_name if ref else name_text
	is_random = is_random_card
	character_reference = ref
	_name_label.text = name_text
	_image.texture = texture
	_image.visible = texture != null
	_question_label.visible = is_random_card
	if is_random_card:
		_background.color = Color(0.2, 0.2, 0.28, 0.8)
		_burst_frame.modulate = Color(0.7, 0.7, 0.8, 0.9)
	else:
		_background.color = Color(0.11, 0.11, 0.17, 0.92)
		_burst_frame.modulate = Color(1, 1, 1, 1)
	_set_selected(_selected, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("pressed", self)
	if event is InputEventMouseMotion:
		emit_signal("hovered", self)

func set_selected(selected: bool) -> void:
	_set_selected(selected, false)

func _set_selected(selected: bool, instant: bool) -> void:
	_selected = selected
	if _tween and _tween.is_running():
		_tween.kill()
	var target_scale := Vector2.ONE
	var border_color := Color(0.39, 0.39, 0.47, 1.0)
	if selected:
		target_scale = Vector2(hover_scale, hover_scale)
		border_color = Color(0.95, 0.95, 1.0, 1.0)
	if instant:
		scale = target_scale
	else:
		_tween = create_tween()
		_tween.tween_property(self, "scale", target_scale, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_border_color = border_color
	queue_redraw()

func set_disabled(disabled: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_PASS
	modulate = Color(0.6, 0.6, 0.6, 0.6) if disabled else Color(1, 1, 1, 1)

func set_burst_texture(texture: Texture2D) -> void:
	_image.texture = texture
	_image.visible = texture != null

func set_name_text(text: String) -> void:
	_name_label.text = text

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _border_color, false, 4.0)
