extends CPUParticles2D

@onready var pointLight: PointLight2D = $PointLight2D

func _process(_delta: float) -> void:
	if emitting == false and pointLight.is_visible_in_tree():
		pointLight.hide()

func emit_at(pos: Vector2, rot: float):
	global_position = pos
	global_rotation = rot
	restart()
	emitting = true
	pointLight.show()
