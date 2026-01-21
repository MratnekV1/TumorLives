class_name Bullet
extends Area2D

var max_range := 1200.0
var speed := 750.0
var _travelled_distance = 0.0

@onready var particles: GPUParticles2D = $GPUParticles2D

func spawn() -> void:
	_travelled_distance = 0.0
	show()
	particles.emitting = true
	set_physics_process(true)
	collision_mask = 1

func _physics_process(delta: float) -> void:
	var distance := speed * delta
	position += transform.x * distance
	
	_travelled_distance += distance
	if _travelled_distance > max_range:
		deactivate()

func deactivate() -> void:
	particles.emitting = false
	hide()
	set_physics_process(false)
	collision_mask = 0


func _on_body_entered(body: Node2D) -> void:
	if(!body.is_in_group("Player") or !body is Player): 
		return
	
	body.take_damage(1, global_position)
	
	deactivate()
