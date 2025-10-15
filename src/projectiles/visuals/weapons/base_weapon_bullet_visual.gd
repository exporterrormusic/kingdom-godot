@tool
extends Node2D
class_name BaseWeaponBulletVisual

var apply_color_callback: Callable = Callable()
var _white_texture: Texture2D = null

func set_apply_color_callback(callback: Callable) -> void:
	apply_color_callback = callback

func set_white_texture(texture: Texture2D) -> void:
	_white_texture = texture
	_apply_texture_if_missing(self)

func configure_visual(params: Dictionary) -> void:
	var direction: Vector2 = params.get("direction", Vector2.RIGHT)
	var radius: float = float(params.get("radius", 4.0))
	var color: Color = params.get("color", Color(1.0, 0.9, 0.4, 1.0))
	var context: Dictionary = params.get("context", {}) if params.has("context") else {}
	update_visual(direction, radius, color, context)

func update_visual(_direction: Vector2, _radius: float, _color: Color, _context: Dictionary = {}) -> void:
	# Intentionally blank. Subclasses override.
	pass

func _apply_color(color: Color, offset: Vector2 = Vector2.ZERO) -> Color:
	if apply_color_callback and apply_color_callback.is_valid():
		return apply_color_callback.call(color, offset)
	return color

func _ensure_sprites_textured(nodes: Array) -> void:
	if nodes.is_empty():
		return
	var texture := _resolve_white_texture()
	for node in nodes:
		if node is Sprite2D and node.texture == null:
			(node as Sprite2D).texture = texture

func _resolve_white_texture() -> Texture2D:
	if _white_texture:
		return _white_texture
	_white_texture = _create_white_texture()
	return _white_texture

func _create_white_texture() -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func _apply_texture_if_missing(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			if sprite.texture == null:
				sprite.texture = _resolve_white_texture()
		if child.get_child_count() > 0:
			_apply_texture_if_missing(child)
