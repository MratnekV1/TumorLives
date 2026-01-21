extends RigidBody2D

const BulletScene := preload("res://Entities/Projectiles/bullet.tscn")
const RANDOM_ANGLE := deg_to_rad(45.0)
@export var pool_size := 1000

var fire_rate := 150.0
var _bullet_pool := []
var _index := 0
var _timer := 0.0

func _ready() -> void:
	for i in pool_size:
		var bullet = BulletScene.instantiate()
		bullet.hide()
		bullet.set_physics_process(false)
		_bullet_pool.append(bullet)
		get_tree().root.add_child.call_deferred(bullet)

func _process(delta: float) -> void:
	_timer += delta
	var time_between_shots = 1.0 / fire_rate
	
	while _timer >= time_between_shots:
		fire_bullet()
		_timer -= time_between_shots

func fire_bullet() -> void:
	var bullet = _bullet_pool[_index]
	
	bullet.global_position = global_position
	bullet.look_at(get_global_mouse_position())
	var offset = randf_range(-RANDOM_ANGLE / 2.0, RANDOM_ANGLE / 2.0)
	bullet.rotation += offset
	
	bullet.spawn()
	_index = (_index + 1) % pool_size
