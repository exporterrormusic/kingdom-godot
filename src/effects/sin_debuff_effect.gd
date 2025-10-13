extends Node2D
class_name SinDebuffEffect

@export var aura_radius: float = 60.0
@export var aura_thickness: float = 5.0
@export var skull_offset: float = 48.0
@export var pulse_speed: float = 3.0
@export var glow_speed: float = 5.0

var _pulse_time: float = 0.0
var _glow_time: float = 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_pulse_time += delta * pulse_speed
	_glow_time += delta * glow_speed
	queue_redraw()

func _draw() -> void:
	var pulse := (sin(_pulse_time) + 1.0) * 0.5
	var glow := (sin(_glow_time) + 1.0) * 0.5
	_draw_aura(pulse)
	_draw_skull(glow)

func _draw_aura(pulse: float) -> void:
	var layers := 3
	for i in range(layers):
		var radius := aura_radius - float(i) * 10.0
		if radius <= 0.0:
			continue
		var alpha := 0.25 + 0.35 * (1.0 - float(i) / float(max(layers - 1, 1)))
		alpha += 0.15 * pulse
		var color := Color(0.72 + 0.08 * float(i), 0.12 + 0.05 * float(i), 0.86, clampf(alpha, 0.0, 0.9))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, aura_thickness)

func _draw_skull(glow: float) -> void:
	var skull_pos := Vector2(0.0, -skull_offset)
	var base_color := Color(1.0, 0.95, 1.0, 0.9)
	var glow_alpha := clampf(0.35 + glow * 0.35, 0.0, 0.7)
	var glow_color := Color(0.85, 0.45, 0.95, glow_alpha)
	draw_circle(skull_pos, 22.0, glow_color)
	draw_circle(skull_pos, 12.0, base_color)
	var eye_offset := Vector2(6.0, -4.0)
	var eye_color := Color(0.24, 0.0, 0.36, 0.85)
	draw_circle(skull_pos + eye_offset, 3.5, eye_color)
	draw_circle(skull_pos - eye_offset, 3.5, eye_color)
	draw_line(skull_pos + Vector2(-5.0, 4.0), skull_pos + Vector2(5.0, 4.0), base_color, 2.0, true)
