extends Camera2D

@export_group("Settings")
@export var shake_fade := 5.0 # How fast the shake fades-out
@export var lean_amount := 0.075 # How fast camera overtakes movement
@export var zoom_speed := 2.0 # How fast camera changes zoom
@export var dynamic_zoom := 0.05 # How much camera shoud move

var _shake_strength := 0.0
var _impact_strength := 0.0
var _base_shake := 0.0

var _rng = RandomNumberGenerator.new()

@onready var player: Player = get_parent()

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	_impact_strength = lerp(_impact_strength, 0.0, shake_fade * delta)
	
	var total_shake = _impact_strength + _base_shake
	
	if total_shake > 0:
		offset = _get_random_offset(total_shake)
		if total_shake < 2.0: 
			offset += player.velocity * lean_amount
	else:
		offset = lerp(offset, player.velocity * lean_amount, delta * 2.0)
		
	var velocity_ratio = player.velocity.length() / player.MAX_SPEED
	var target_zoom = 1.0 - (velocity_ratio * dynamic_zoom)
	zoom = lerp(zoom, Vector2(target_zoom, target_zoom), delta * zoom_speed)

func apply_impact(strength: float) -> void:
	if strength > _impact_strength:
		_impact_strength = strength
		
func set_base_shake(strength: float) -> void:
	_base_shake = strength
		
func apply_shake(strength: float) -> void:
	_shake_strength = strength
	
func _get_random_offset(strength: float) -> Vector2:
	return Vector2(
		_rng.randf_range(-strength, strength), 
		_rng.randf_range(-strength, strength)
		)
