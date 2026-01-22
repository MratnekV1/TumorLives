extends Camera2D

@export_group("Settings")
@export var shake_fade := 5.0 # How fast the shake fades-out
@export var lean_amount := 0.075 # How fast camera overtakes movement
@export var zoom_speed := 2.0 # How fast camera changes zoom
@export var dynamic_zoom := 0.05 # How much camera shoud move

var _shake_strength := 0.0
var _impact_strength := 0.0
var _base_shake := 0.0

# Stealth
var _stealth_zoom_offset := 1.0
var _stealth_zoom_tween: Tween
var _stealth_breath_value := 0.0

var _rng = RandomNumberGenerator.new()

@onready var player: Player = get_parent()

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	_count_stealth_breathing(delta)
	_count_offset(delta)
		
	_set_zoom(delta)
	
	_shake_strength = lerp(_shake_strength, 0.0, delta * 5.0)
	
func _set_zoom(delta: float) -> void:
	var velocity_ratio = player.velocity.length() / player.MAX_SPEED
	var target_zoom = (1.0 - (velocity_ratio * dynamic_zoom)) * _stealth_zoom_offset
	target_zoom += _stealth_breath_value
	zoom = lerp(zoom, Vector2(target_zoom, target_zoom), delta * zoom_speed)

func _count_offset(delta: float) -> void:
	_impact_strength = lerp(_impact_strength, 0.0, shake_fade * delta)
	
	var total_shake = _impact_strength + _base_shake + _shake_strength
	
	if total_shake > 0:
		offset = _get_random_offset(total_shake)
		if total_shake < 2.0: 
			offset += player.velocity * lean_amount
	else:
		offset = lerp(offset, player.velocity * lean_amount, delta * 2.0)

func _count_stealth_breathing(delta: float) -> void:
	if player.is_dimming and player.velocity.length() < 10.0:
		_stealth_breath_value = sin(Time.get_ticks_msec() * 0.0015) * 0.015
	else:
		_stealth_breath_value = lerp(_stealth_breath_value, 0.0, delta * 5.0)

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

func set_stealth_zoom(target: float, in_duration: float, out_duration: float) -> void:
	if _stealth_zoom_tween:
		_stealth_zoom_tween.kill()
	
	_stealth_zoom_tween = create_tween()
	
	if target > 1.0:
		_stealth_zoom_tween.tween_property(self, "_stealth_zoom_offset", target, in_duration)
		_stealth_zoom_tween.tween_property(self, "_stealth_zoom_offset", 0.95, out_duration)
	else:
		_stealth_zoom_tween.tween_property(self, "_stealth_zoom_offset", 1.0, in_duration)
		
