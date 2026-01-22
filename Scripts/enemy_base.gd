extends RigidBody2D

const BulletScene := preload("res://Entities/Projectiles/bullet.tscn")
const RANDOM_ANGLE := deg_to_rad(45.0)
@export var pool_size := 1000

# Impact Particles
const HitParticlesScene := preload("res://Entities/Projectiles/bullet_impact_particles.tscn")
var _particle_pool := []
var _p_index := 0
@export var p_pool_size := 100

var fire_rate := 125.0
var _bullet_pool := []
var _index := 0
var _timer := 0.0

func _ready() -> void:
	prepare_pool()
		
func prepare_pool() -> void:
	_prepare_particles()
	
	for i in pool_size:
		var bullet = BulletScene.instantiate()
		bullet.hide()
		bullet.set_physics_process(false)
		_bullet_pool.append(bullet)
		get_tree().root.add_child.call_deferred(bullet)
	
		if i % 30 == 0:
			await get_tree().process_frame

func _prepare_particles() -> void:
	for i in p_pool_size:
		var p = HitParticlesScene.instantiate()
		_particle_pool.append(p)
		get_tree().root.add_child.call_deferred(p)
		
func spawn_hit_effect(pos: Vector2, normal: Vector2):
	var p = _particle_pool[_p_index]
	
	p.emit_at(pos, normal.angle())
	_p_index = (_p_index + 1) % p_pool_size

func _process(delta: float) -> void:
	_timer += delta
	var time_between_shots = 1.0 / fire_rate
	
	while _timer >= time_between_shots:
		fire_bullet()
		_timer -= time_between_shots

func fire_bullet() -> void:
	if _index >= _bullet_pool.size():
		return
	
	var bullet = _bullet_pool[_index]
	
	bullet.collision_mask = 1
	bullet.shooter = self
	bullet.global_position = global_position
	bullet.look_at(get_global_mouse_position())
	var offset = randf_range(-RANDOM_ANGLE / 2.0, RANDOM_ANGLE / 2.0)
	bullet.rotation += offset
	
	bullet.spawn()
	_index = (_index + 1) % pool_size
