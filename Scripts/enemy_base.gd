extends CharacterBody2D

# --- Configuration ---
@export_group("Detection")
@export var detection_radius := 1200.0
@export var attacking_range := 600.0
@export var field_of_view := 180.0
@export var detection_speed := 1.5      # Bazowa prędkość wykrywania
@export var lose_speed := 0.5           # Prędkość zapominania
@export var hearing_sensitivity := 1.0  
@export var stealth_vision_modifier := 0.2 # Mnożnik wykrywania, gdy gracz jest w stealth (0.2 = bardzo wolno)

@export_group("Combat")
@export var preferred_attack_distance := 450.0
@export var strafe_speed := 350.0
@export var fire_rate := 10.0 
@export var bullet_pool_size := 100
@export var particle_pool_size := 50
@export var damage := 10.0


@export_group("Movement")
@export var patrol_speed := 320.0
@export var chase_speed := 450.0
@export var acceleration := 2000.0
@export var friction := 1500.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var _patrol_positions: Array[Vector2] = []

# --- OUTSIDE VARIABLES ---
var player: Node2D = null
var last_known_position := Vector2.ZERO
var detection_level := 0.0

# Pooling
const BulletScene := preload("res://Entities/Projectiles/bullet.tscn")
const HitParticlesScene := preload("res://Assets/Particles/bullet_impact_particles.tscn")
const RANDOM_ANGLE := deg_to_rad(5.0)

var _bullet_pool: Array = []
var _particle_pool: Array = []
var _b_index := 0
var _p_index := 0

# Shooting
var _shoot_timer := 0.0

# States
enum States {IDLE, PATROLLING, CHASING, ALERTED, ATTACKING}
var current_state = States.PATROLLING
var current_waypoint_idx := 0
var _is_navigation_ready := false

@onready var state_timer: Timer = $Timer

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	call_deferred("_prepare_pools")
	
	if _patrol_positions.is_empty():
		current_state = States.IDLE

func _prepare_pools() -> void:
	var pool_container = Node.new()
	pool_container.name = "EnemyPool_" + str(get_instance_id())
	get_tree().current_scene.add_child(pool_container)
	
	for i in bullet_pool_size:
		var bullet = BulletScene.instantiate()
		bullet.hide()
		bullet.set_process(false)
		bullet.set_physics_process(false)
		_bullet_pool.append(bullet)
		pool_container.add_child(bullet)
	
	for i in particle_pool_size:
		var p = HitParticlesScene.instantiate()
		_particle_pool.append(p)
		pool_container.add_child(p)

func _physics_process(delta: float) -> void:
	if not _is_navigation_ready:
		if NavigationServer2D.map_get_iteration_id(nav_agent.get_navigation_map()) > 0:
			_is_navigation_ready = true
		else:
			return
	
	_update_vision_logic(delta)
	_handle_state_machine(delta)
	move_and_slide()

func _setup_patrol_points() -> void:
	_patrol_positions.clear()
	var current_node = get_parent()
	var patrol_node = null
	
	while current_node != null and current_node != get_tree().root:
		patrol_node = current_node.get_node_or_null("PatrollingPoints")
		if patrol_node: break
		current_node = current_node.get_parent()
	
	if patrol_node:
		patrol_node.force_update_transform()
			
		for child in patrol_node.get_children():
			if child is Marker2D or child is Node2D:
				_patrol_positions.append(child.global_position)
		
		if not _patrol_positions.is_empty():
			current_state = States.PATROLLING
			current_waypoint_idx = 0
			nav_agent.target_position = _patrol_positions[0]

# ---- STATE MACHINE----- #

func _handle_state_machine(delta: float) -> void:
	match current_state:
		States.IDLE:
			_handle_idle(delta)
		States.PATROLLING:
			_handle_patrolling(delta)
		States.CHASING:
			_handle_chasing(delta)
		States.ALERTED:
			_handle_alerted(delta)
		States.ATTACKING:
			_handle_attacking(delta)

func _handle_idle(delta: float) -> void:
	_apply_friction(delta)

func _handle_patrolling(delta: float) -> void:
	if _patrol_positions.is_empty():
		current_state = States.IDLE
		return
	
	var target_pos = _patrol_positions[current_waypoint_idx]
	
	if not nav_agent.is_navigation_finished():
		_move_towards(target_pos, patrol_speed, delta)
		_look_at_smooth(target_pos, delta, true)
	else:
		_apply_friction(delta)
		
		if velocity.length() < 20.0:
			current_waypoint_idx = (current_waypoint_idx + 1) % _patrol_positions.size()
			current_state = States.IDLE
			state_timer.start(2.0)
			
	var dist_to_wp = global_position.distance_to(target_pos)
	
	if dist_to_wp > 80.0: # Margin CHANGE
		_move_towards(target_pos, patrol_speed, delta)
		_look_at_smooth(target_pos, delta, true)
	else:
		_apply_friction(delta)
		if velocity.length() < 20.0:
			current_waypoint_idx = (current_waypoint_idx + 1) % _patrol_positions.size()
			current_state = States.IDLE
			if state_timer.is_stopped():
				state_timer.start(2.0)

func _handle_chasing(delta: float) -> void:
	if not player: return
	
	var can_see = _can_see_player()
	var nav_map = nav_agent.get_navigation_map()
	
	if can_see:
		var safe_pos = NavigationServer2D.map_get_closest_point(nav_map, player.global_position)
		last_known_position = safe_pos
		detection_level = 1.0
	
	var dist_to_target = global_position.distance_to(last_known_position)
	
	if dist_to_target < 250.0 and can_see:
		current_state = States.ATTACKING
		_apply_friction(delta)
		return
	
	_move_towards(last_known_position, chase_speed, delta)
	_look_at_smooth(last_known_position, delta, false)
	
	if not can_see and nav_agent.is_navigation_finished():
		current_state = States.ALERTED
		state_timer.start(3.0)

func _handle_alerted(delta: float) -> void:
	_apply_friction(delta)
	
	var look_dir = (last_known_position - global_position).normalized()
	# Lekki ruch "paniczny" rozglądania się
	rotation = lerp_angle(rotation, look_dir.angle() + sin(Time.get_ticks_msec() * 0.005) * 0.5, 5 * delta)
	
	if _can_see_player():
		current_state = States.CHASING

func _handle_attacking(delta: float) -> void:
	if not player: 
		current_state = States.IDLE
		return
		
	_look_at_smooth(player.global_position, delta)
	
	var dist_to_player = global_position.distance_to(player.global_position)
	var dir_to_player = global_position.direction_to(player.global_position)
	
	var strafe_dir = Vector2(dir_to_player.y, -dir_to_player.x)
	var side_movement = sin(Time.get_ticks_msec() * 0.002) * 200.0
	
	var target_point = player.global_position
	
	if dist_to_player < preferred_attack_distance:
		target_point = global_position - (dir_to_player * 100.0)

	target_point += strafe_dir * side_movement
	
	_move_towards(target_point, chase_speed * 0.8, delta)

	if dist_to_player > detection_radius or not _can_see_player():
		current_state = States.CHASING
		return
		
	_shoot_timer -= delta
	if _shoot_timer <= 0:
		fire_bullet()
		_shoot_timer = 1.0 / fire_rate

# --- DETECTION --- #

func _update_vision_logic(delta: float) -> void:
	var can_see = _can_see_player()
	
	if can_see:
		var multiplier = 1.0
		
		var is_stealth = false
		if player.has_method("is_stealthing"):
			is_stealth = player.is_stealthing()
		elif "is_dimming" in player:
			is_stealth = player.is_dimming
			
		if is_stealth:
			multiplier = stealth_vision_modifier
		
		detection_level += detection_speed * multiplier * delta
	else:
		detection_level -= lose_speed * delta
	
	detection_level = clamp(detection_level, 0.0, 1.0)
	
	if detection_level >= 1.0 and current_state in [States.IDLE, States.PATROLLING, States.ALERTED]:
		current_state = States.CHASING
		if player: last_known_position = player.global_position

func listen_to_noise(noise_pos: Vector2, loudness: float):
	var dist = global_position.distance_to(noise_pos)
	
	if dist < loudness * hearing_sensitivity:
		last_known_position = noise_pos
		
		if current_state == States.IDLE or current_state == States.PATROLLING:
			current_state = States.ALERTED
			detection_level = max(detection_level, 0.5)
			if state_timer.is_stopped():
				state_timer.start(3.0)

# ---- HELPERS --- #

func _move_towards(target: Vector2, spd: float, delta: float):
	if nav_agent.target_position.distance_to(target) > 20.0:
		nav_agent.target_position = target
		
		if nav_agent.is_target_reachable() == false:
			current_state = States.ALERTED
			state_timer.start(2.0)
			return
	
	if nav_agent.is_navigation_finished():
		return

	var next_path_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	
	var desired_velocity = direction * spd
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		velocity = velocity.move_toward(desired_velocity, acceleration * delta)

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = velocity.move_toward(safe_velocity, acceleration * get_physics_process_delta_time())

func _apply_friction(delta: float):
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func _look_at_smooth(target_pos: Vector2, delta: float, look_at_path: bool = false):
	var target_angle: float
	
	if look_at_path:
		var next_point = nav_agent.get_next_path_position()
		target_angle = (next_point - global_position).angle()
	else:
		target_angle = (target_pos - global_position).angle()
	
	rotation = lerp_angle(rotation, target_angle, 20.0 * delta)

func _can_see_player() -> bool:
	if not player: return false
	
	var dist = global_position.distance_to(player.global_position)
	if dist > detection_radius: return false
	
	var direction_to_player = global_position.direction_to(player.global_position)
	var forward_direction = Vector2.RIGHT.rotated(rotation)
	var angle_to_player = forward_direction.angle_to(direction_to_player)
	
	if abs(angle_to_player) > deg_to_rad(field_of_view / 2.0):
		return false

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self.get_rid()]
	query.collision_mask = 3 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.collider == player
	return false

func fire_bullet() -> void:
	if _bullet_pool.is_empty(): return
	
	var bullet = _bullet_pool[_b_index]
	
	bullet.global_position = global_position
	
	var direction = (player.global_position - global_position).normalized()
	var angle_offset = randf_range(-RANDOM_ANGLE, RANDOM_ANGLE)
	bullet.rotation = direction.angle() + angle_offset
	
	if bullet.has_method("spawn"):
		bullet.spawn(self)
	else:
		bullet.show()
		bullet.set_physics_process(true)
	
	_b_index = (_b_index + 1) % bullet_pool_size

func _on_timer_timeout() -> void:
	match current_state:
		States.IDLE:
			current_state = States.PATROLLING
		States.ALERTED:
			current_state = States.PATROLLING
			detection_level = 0.0

func spawn_hit_effect(pos: Vector2, normal: Vector2) -> void:
	if _particle_pool.is_empty(): return
	
	var particles = _particle_pool[_p_index]
	particles.emit_at(pos, normal.angle())
	
	_p_index = (_p_index + 1) % particle_pool_size
