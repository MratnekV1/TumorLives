class_name Player
extends CharacterBody2D

const MAX_SPEED = 800.0
const ACCELERATION = 3000.0  # How fast player moves
const FRICTION = 1600.0 # How fast player stops

# Dash Settings
const DASH_SPEED = 1600.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 1.2
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector2.ZERO

var player_max_hp := 100
var player_current_hp := player_max_hp

enum State {IDLE, WALK, DASHING, STEALTH, DYING}
var current_state: State = State.IDLE

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var impact_overlay: ColorRect = $CanvasLayer/ImpactFrame
@onready var aberration_rect: ColorRect = $CanvasLayer/ChromaticAberation
@onready var vignette: ColorRect = $CanvasLayer/Vignette
@onready var camera: Camera2D = $Camera2D

@onready var ghost_material = preload("res://Shaders/invertedColorShader.gdshader")

# Light / Stealth
@onready var lightBulb: PointLight2D = $LightBulb
var dim_tween: Tween
var is_dimming := false
var stealth_time_left := 0.0
var max_stealth_duration := 5.0
signal stealth_timeout(pos: Vector2)

func _process(delta: float) -> void:
	match current_state:
		State.STEALTH:
			_handle_stealth_logic(delta)
			
	_update_vignette_pulse()
	_apply_low_hp_camera_shake(delta)

func _physics_process(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			_on_dash_ready()
	
	match current_state:
		State.IDLE, State.WALK, State.STEALTH:
			_handle_movement(delta)
			_handle_diming()
			_handle_dash_input()
		State.DASHING:
			_handle_dash_physics(delta)
			
	_handle_squash(delta)
	move_and_slide()
	_update_state()
	
func _update_state() -> void:
	if current_state == State.DASHING or current_state == State.DYING:
		return
	
	if is_dimming:
		current_state = State.STEALTH
	elif velocity.length() > 10.0:
		current_state = State.WALK
	else:
		current_state = State.IDLE	

func _handle_movement(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
		dash_direction = direction.normalized()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

# Stealth Logic

func _handle_stealth_logic(delta: float) -> void:
	if is_dimming:
		stealth_time_left -= delta
		
		if stealth_time_left < 2.0 and stealth_time_left > 0:
			var stealth_shake_intensity = (2.0 - stealth_time_left) * 2.0
			camera.apply_shake(stealth_shake_intensity)
		
		if stealth_time_left <= 0:
			stealth_timeout.emit(global_position)
			take_damage(20, global_position + Vector2.DOWN)
			_stop_stealth(1.0, 1.5)

func _handle_diming() -> void:
	if Input.is_action_just_pressed("ctr_dim"):
		_start_stealth(0.4, 0.3)
	elif Input.is_action_just_released("ctr_dim") and stealth_time_left > 0:
		_stop_stealth(1.0, 0.5)

func _start_stealth(target_energy: float, duration: float) -> void:
	is_dimming = true
	stealth_time_left = max_stealth_duration
	_animate_light(target_energy, duration)
	_animate_aberration(2.2, duration)
	
	camera.set_stealth_zoom(1.25, 0.3, max_stealth_duration)

func _stop_stealth(target_energy: float, duration: float) -> void:
	is_dimming = false
	stealth_time_left = 0
	_animate_light(target_energy, duration)
	_animate_aberration(0.5, duration)
	camera.set_stealth_zoom(1.0, 0.5, 0.0)
	
func _animate_light(target: float, duration: float) -> void:
	if dim_tween:
		dim_tween.kill()
	
	dim_tween = create_tween()
	dim_tween.tween_property(lightBulb, "energy", target, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

func is_stealthing() -> bool:
	return is_dimming or current_state == State.STEALTH

# Dash Logic

func _handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		if dash_direction == Vector2.ZERO:
			dash_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			dash_direction = dash_direction.normalized()
		
		_start_dash()

func _start_dash() -> void:
	current_state = State.DASHING
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	
	_apply_glitch_effect()
	
	camera.zoom_speed = 10.0
	camera.apply_impact(8.0)
	
	if is_dimming:
		stealth_time_left -= 1.0

func _handle_dash_physics(delta: float) -> void:
	velocity = dash_direction * DASH_SPEED
	dash_timer -= delta
	
	if Engine.get_frames_drawn() % 1 == 0:
		_spawn_dash_ghost()

	if dash_timer <= 0:
		current_state = State.IDLE
		velocity = dash_direction * MAX_SPEED
		camera.zoom_speed = 2.0

func _spawn_dash_ghost() -> void:
	var ghost = sprite.duplicate()
	get_parent().add_child(ghost)
	ghost.global_position = sprite.global_position
	
	ghost.material = ghost_material
	
	ghost.modulate.a = 0.5
	ghost.z_index = -6
	var t = create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, 0.3)
	t.tween_callback(ghost.queue_free)

func _on_dash_ready() -> void:
	var ghost = sprite.duplicate()
	add_child(ghost)
	
	ghost.global_position = sprite.global_position
	
	ghost.material = ghost_material
	ghost.scale = sprite.scale * 1.25
	ghost.modulate.a = 0.3
	ghost.z_index = 5
	
	camera.apply_impact(2.0)
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(ghost, "scale", sprite.scale, 0.25)\
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	t.tween_property(ghost, "modulate:a", 0.0, 0.25)
	t.set_parallel(false)
	t.tween_callback(ghost.queue_free)

# Others

func _handle_squash(delta: float) -> void:
	var target_scale : Vector2
	
	if current_state == State.DASHING:
		if abs(dash_direction.y) > abs(dash_direction.x):
			target_scale = Vector2(0.23, 0.4)
		else:
			target_scale = Vector2(0.4, 0.15)
			
	elif is_dimming:
		target_scale = Vector2(0.32, 0.2)
	else:
		var velocity_ratio = velocity.length() / MAX_SPEED
		target_scale = Vector2(.26 + (velocity_ratio * .02), .26 - (velocity_ratio * .01))
	
	sprite.scale = sprite.scale.lerp(target_scale, delta * 12.0)
	
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

func _animate_aberration(target_value: float, duration: float) -> void:
	var mat = aberration_rect.material as ShaderMaterial
	if not mat: return
	
	var tween = create_tween()
	tween.tween_property(mat, "shader_parameter/offset", target_value, duration)\
		.set_trans(Tween.TRANS_SINE)

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
