extends BasicEnemy
class_name BossEnemy

## Boss variant with larger scale, resilient health pool, and an enraged phase.
## Keeps the same defeated signal contract as BasicEnemy but tweaks tuning defaults.

@export var boss_max_health: int = 80
@export var boss_move_speed: float = 180.0
@export var boss_contact_damage: int = 32
@export var boss_scale_multiplier: float = 2.4
@export_range(0.1, 0.9, 0.05) var enraged_threshold: float = 0.35
@export var enraged_speed_multiplier: float = 1.25
@export var enraged_contact_multiplier: float = 1.4
@export var enraged_tint: Color = Color(1.0, 0.55, 0.55, 1.0)

var _enraged: bool = false

func _ready() -> void:
	# Configure baseline boss tuning prior to the base enemy setup running.
	max_health = boss_max_health
	move_speed = boss_move_speed
	contact_damage = boss_contact_damage
	visual_scale_multiplier = boss_scale_multiplier
	hurt_flash_intensity = 1.35
	super._ready()
	add_to_group("boss_enemies")

func _physics_process(delta: float) -> void:
	if not _enraged and _current_health <= int(round(float(boss_max_health) * enraged_threshold)):
		_enrage()
	super._physics_process(delta)

func _enrage() -> void:
	_enraged = true
	move_speed = boss_move_speed * enraged_speed_multiplier
	contact_damage = int(round(float(boss_contact_damage) * enraged_contact_multiplier))
	if _animator:
		_base_modulate = enraged_tint
		_animator.modulate = enraged_tint
		_update_glow_for_tint()
