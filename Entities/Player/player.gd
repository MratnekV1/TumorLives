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
var player_current_hp := 100

enum State {IDLE, WALK, DASHING, STEALTH, DYING, INFECTING}
var current_state: State = State.IDLE

# Animation
var last_direction: Vector2
var current_animation := "idle"
const RUN_THRESHOLD := 230
const WALK_TRESHOLD := 50

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var impact_overlay: ColorRect = $CanvasLayer/ImpactFrame
@onready var aberration_rect: ColorRect = $CanvasLayer/ChromaticAberation
@onready var death_overlay: ColorRect = $CanvasLayer/DeathOverlay
@onready var vignette: ColorRect = $CanvasLayer/Vignette
@onready var camera: Camera2D = $Camera2D
@onready var infection_area: Area2D = $InfectionArea

@onready var ghost_material = preload("res://Shaders/invertedColorShader.gdshader")

# Light / Stealth
@onready var lightBulb: PointLight2D = $LightBulb
var dim_tween: Tween
var is_dimming := false
var stealth_time_left := 5.0
var max_stealth_duration := 5.0
const STEALTH_REGEN_SPEED = 0.8
const STEALTH_MIN_THRESHOLD = 1.0

signal stealth_timeout(pos: Vector2)

# Infection
@export var infection_noise_loudness := 800.0
@export var infection_noise_interval := 0.2
var _noise_timer := 0.0
var infection_particles_scene = preload("res://Assets/Particles/infection_effect.tscn")
var active_infection_effects = {}


func _ready() -> void:
	await get_tree().process_frame
	
	set_collision_layer_value(3, true)
	set_collision_mask_value(3, true)

func _process(delta: float) -> void:
	match current_state:
		State.STEALTH:
			_handle_stealth_logic(delta)
			
	Animations.choose_animation_direction(last_direction, sprite, current_animation)
	_update_vignette_pulse()
	_apply_low_hp_camera_shake(delta)

func _physics_process(delta: float) -> void:
	if current_state == State.DYING:
		return
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			_on_dash_ready()
	
	_regenerate_stealth(delta)
	
	match current_state:
		State.IDLE, State.WALK, State.STEALTH, State.INFECTING:
			_handle_movement(delta)
			_handle_diming()
			_handle_dash_input()
			_handle_infection_input(delta)
		State.DASHING:
			_handle_dash_physics(delta)
			
	_handle_squash(delta)
	move_and_slide()
	_update_state()
	
func _update_state() -> void:
	if current_state == State.DYING: return
	if player_current_hp <= 0:
		current_state = State.DYING
		_handle_dying()
		
	if current_state == State.DASHING: return
	if current_state == State.INFECTING: return
		
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
		last_direction = direction
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		
	if velocity.length() > RUN_THRESHOLD:
		current_animation = "run"
	elif velocity.length() > WALK_TRESHOLD:
		current_animation = "walk"
	else:
		current_animation = "idle"

# Stealth Logic

func _handle_stealth_logic(delta: float) -> void:
	if is_dimming:
		stealth_time_left -= delta
		
		if stealth_time_left < 2.0 and stealth_time_left > 0:
			var stealth_shake_intensity = (2.0 - stealth_time_left) * 2.0
			camera.apply_shake(stealth_shake_intensity)
		
		if stealth_time_left <= 0:
			stealth_time_left = 0
			stealth_timeout.emit(global_position)
			take_damage(20, global_position + Vector2.DOWN)
			_stop_stealth(1.0, 1.5)

func _handle_diming() -> void:
	if Input.is_action_just_pressed("ctr_dim") and stealth_time_left > STEALTH_MIN_THRESHOLD:
		_start_stealth(0.4, 0.3)
	elif Input.is_action_just_released("ctr_dim") and is_dimming:
		_stop_stealth(1.0, 0.5)

func _start_stealth(target_energy: float, duration: float) -> void:
	is_dimming = true
	_animate_light(target_energy, duration)
	_animate_aberration(2.2, duration)
	
	camera.set_stealth_zoom(1.25, 0.3, stealth_time_left)

func _stop_stealth(target_energy: float, duration: float) -> void:
	is_dimming = false
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

func _regenerate_stealth(delta: float) -> void:
	if stealth_time_left > max_stealth_duration or is_stealthing(): return
		
	stealth_time_left += delta * STEALTH_REGEN_SPEED
	stealth_time_left = min(stealth_time_left, max_stealth_duration)

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
	set_collision_layer_value(3, false)
	set_collision_mask_value(3, false)
	
	camera.zoom_speed = 10.0
	camera.apply_impact(8.0)
	
	
	if is_dimming:
		stealth_time_left -= 1.0

func _handle_dash_physics(delta: float) -> void:
	velocity = dash_direction * DASH_SPEED
	dash_timer -= delta
	
	#if Engine.get_frames_drawn() % 1 == 0:
	_spawn_dash_ghost()

	if dash_timer <= 0:
		set_collision_layer_value(3, true)
		set_collision_mask_value(3, true)
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

# Infection Logic

func _handle_infection_input(delta: float) -> void:
	if Input.is_action_pressed("infect"):
		current_state = State.INFECTING
		var areas = infection_area.get_overlapping_areas()
		var current_targets = []
		var is_actually_infecting = false
		
		for area in areas:
			var is_done = area.get("is_fully_infected")
			var can_be_infected = area.has_method("apply_infection")
			
			if can_be_infected and not is_done:
				current_targets.append(area)
				_apply_infection(area, delta)
				is_actually_infecting = true
			elif active_infection_effects.has(area):
					_remove_single_effect(area)
		
		if is_actually_infecting:
			_emit_infection_noise(delta)
			
		_remove_out_of_range_infection(current_targets)
		_update_effect_position()
		
		velocity *= 0.5
	elif current_state == State.INFECTING:
		_clear_infection_effects()
		current_state = State.IDLE
		_noise_timer = 0.0

func _emit_infection_noise(delta: float) -> void:
		_noise_timer -= delta
		if _noise_timer <= 0:
			get_tree().call_group("Enemies", "listen_to_noise", global_position, infection_noise_loudness)
			camera.apply_shake(1.0)
			_noise_timer = infection_noise_interval

func _apply_infection(area: Area2D, delta: float) -> void:
		area.apply_infection(60.0 * delta)
		
		if not active_infection_effects.has(area):
			var fx = infection_particles_scene.instantiate()
			fx.global_position = global_position
			fx.look_at(area.global_position)
			
			get_parent().add_child(fx)
			fx.target = area
			active_infection_effects[area] = fx

func _remove_out_of_range_infection(current_targets) -> void:
	var active_targets = active_infection_effects.keys()
	for target_node in active_targets:
			if target_node not in current_targets:
				_remove_single_effect(target_node)

func _remove_single_effect(area):
	if active_infection_effects.has(area):
		var fx = active_infection_effects[area]
		if is_instance_valid(fx):
			fx.target = null
		active_infection_effects.erase(area)

func _update_effect_position() -> void:
	for target_node in active_infection_effects:
			active_infection_effects[target_node].global_position = global_position

func _clear_infection_effects():
	for fx in active_infection_effects.values():
		if is_instance_valid(fx):
			fx.target = null
	active_infection_effects.clear()

# Dying

func _handle_dying() -> void:
	velocity = Vector2.ZERO
	
	Engine.time_scale = 0.00001
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	camera.apply_impact(20.0)
	
	tween.tween_property(death_overlay, "modulate:a", 1.5, 1.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
	tween.tween_callback(func():
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://Scenes/death_screen.tscn")
	)

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
	if player_current_hp > 0:
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
		mat.set_shader_parameter("vignette_color", Color(0.063, 0.118, 0.051, 0.4))

func _apply_low_hp_camera_shake(_delta: float) -> void:
	var health_low_factor = 1.0 - (float(player_current_hp) / player_max_hp)
	if health_low_factor > 0.7:
		var intensity = (health_low_factor - 0.7) * 5.0
		camera.set_base_shake(intensity)
	else:
		camera.set_base_shake(0.0)
