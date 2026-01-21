class_name Player
extends CharacterBody2D

const MAX_SPEED = 500.0
const ACCELERATION = 3000.0  # How fast player moves
const FRICTION = 800.0 # How fast player stops

var player_max_hp := 100
var player_current_hp := player_max_hp

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var impact_overlay: ColorRect = $CanvasLayer/ImpactFrame
@onready var aberration_rect: ColorRect = $CanvasLayer/ChromaticAberation
@onready var vignette: ColorRect = $CanvasLayer/Vignette
@onready var camera: Camera2D = $Camera2D

func _process(delta: float) -> void:
	_update_vignette_pulse()
	_apply_low_hp_camera_shake(delta)

func _physics_process(delta: float) -> void:
	_handle_squash(delta)
	_handle_movement(delta)
	move_and_slide()
	
func _handle_movement(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

func _handle_squash(delta: float) -> void:
	var velocity_ratio = velocity.length() / MAX_SPEED
	
	var target_scale = Vector2(
		.26 + (velocity_ratio * .02),
		.26 - (velocity_ratio * .01)
	)
	
	sprite.scale = sprite.scale.lerp(target_scale, delta * 10.0)
	

func take_damage(ammount: int, knockback_source_pos: Vector2) -> void:
	player_current_hp = clamp(player_current_hp - ammount, 0, player_max_hp)
	_apply_flash() 
	_apply_glitch_effect()
	_apply_impact_frame()
	
	camera.apply_impact(15.0)
	
	# Knockback
	var knockback_strength = 500.0
	var knockback_dir = global_position.direction_to(knockback_source_pos) * -1
	velocity = knockback_dir * knockback_strength

func _apply_flash() -> void:
	var mat = sprite.material as ShaderMaterial
	if not mat: return
	
	var tween = create_tween()
	mat.set_shader_parameter("active", true)
	tween.tween_interval(0.1)
	tween.tween_callback(func(): mat.set_shader_parameter("active", false))

func _apply_impact_frame() -> void:
	impact_overlay.modulate.a = 0.5
	Engine.time_scale = 0.05
	
	await get_tree().create_timer(0.05, true, false, true).timeout
	
	impact_overlay.modulate.a = 0.0
	Engine.time_scale = 1.0

func _apply_glitch_effect() -> void:
	var mat = aberration_rect.material as ShaderMaterial
	var tween = create_tween()
	
	tween.tween_property(mat, "shader_parameter/offset", 1.5, 0.05)
	tween.tween_property(mat, "shader_parameter/offset", .5, 0.4).set_trans(Tween.TRANS_SINE)

func _update_vignette_pulse() -> void:
	var mat = vignette.material as ShaderMaterial
	if not mat: return
	
	var health_low_factor = 1.0 - (float(player_current_hp) / player_max_hp)
	
	if health_low_factor > 0.7:
		var pulse = (sin(Time.get_ticks_msec() * 0.007) + 1.0) * .3
		var target_softness = 0.25 + (pulse * health_low_factor * 0.2)
		
		mat.set_shader_parameter("softness", target_softness)
		mat.set_shader_parameter("vignette_color", Color(0.5 * health_low_factor, 0, 0, 0.7))
	else:
		mat.set_shader_parameter("softness", 0.25)
		mat.set_shader_parameter("vignette_color", Color(0.196, 0.196, 0.404, 0.396))

func _apply_low_hp_camera_shake(_delta: float) -> void:
	var health_low_factor = 1.0 - (float(player_current_hp) / player_max_hp)
	if health_low_factor > 0.7:
		var intensity = (health_low_factor - 0.7) * 5.0
		camera.set_base_shake(intensity)
	else:
		camera.set_base_shake(0.0)
