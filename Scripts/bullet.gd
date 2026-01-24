class_name Bullet
extends Area2D

var max_range := 1200.0
var speed := 750.0
var _travelled_distance = 0.0

var shooter: Node2D

@onready var raycast : RayCast2D = $RayCast2D

func spawn(p_shooter: Node2D = null) -> void:
	shooter = p_shooter
	_travelled_distance = 0.0
	show()
	set_physics_process(true)
	if shooter:
		raycast.add_exception(shooter)
	
	collision_mask = 1 + 4
	raycast.collision_mask = collision_mask
	raycast.enabled = true

func _physics_process(delta: float) -> void:
	var distance := speed * delta
	position += transform.x * distance
	
	_travelled_distance += distance
	if _travelled_distance > max_range:
		deactivate()
		
	if raycast.is_colliding():
		var point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal() 
		
		if is_instance_valid(shooter) and shooter.has_method("spawn_hit_effect"):
			shooter.spawn_hit_effect(point, normal)
		
		deactivate()

func deactivate() -> void:
	hide()
	set_physics_process(false)
	collision_mask = 0
	raycast.enabled = false

func _on_body_entered(body: Node2D) -> void:	
	if body == shooter or body.is_in_group("Bullet"):
		return
		
	if body is Player:
		var hit_normal = -transform.x
		if is_instance_valid(shooter) and shooter.has_method("spawn_hit_effect"):
			shooter.spawn_hit_effect(global_position, hit_normal)
		
		body.take_damage(1, global_position)
	
	deactivate()
