extends CPUParticles2D

var target: Node2D = null
var stopping := false

func _process(_delta):
	if is_instance_valid(target):
		look_at(target.global_position)
		
		var dist = global_position.distance_to(target.global_position)
		initial_velocity_min = dist * 2.0 
		initial_velocity_max = dist * 2.5
		
		lifetime = 0.5 
	else:
		_finish_and_die()
		
func _finish_and_die():
	if stopping: return
	
	stopping = true
	emitting = false
	var wait_time = lifetime
	get_tree().create_timer(wait_time).timeout.connect(queue_free)
