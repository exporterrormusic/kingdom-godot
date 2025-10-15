@tool
extends "res://src/projectiles/visuals/laser_bullet_visual.gd"
class_name SniperSpecialBulletVisual

@export var preview_radius: float = 6.5
@export var preview_color: Color = Color(0.7, 0.92, 1.0, 1.0)
@export var preview_direction: Vector2 = Vector2.RIGHT
@export var special_override: bool = true

func _ready() -> void:
	if Engine.is_editor_hint():
		update_visual(preview_direction, preview_radius, preview_color, {"is_special": special_override})

func configure_visual(params: Dictionary) -> void:
	var direction: Vector2 = params.get("direction", Vector2.RIGHT)
	var radius: float = float(params.get("radius", preview_radius))
	var color: Color = params.get("color", preview_color)
	var context: Dictionary = params.get("context", {}) if params.has("context") else {}
	update_visual(direction, radius, color, context)
