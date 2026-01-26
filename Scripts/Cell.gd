extends Area2D

var infection_level := 0.0
var max_infection := 100.0
var is_fully_infected := false

@onready var sprite: Sprite2D = $Sprite/Sprite2D
@onready var scared_area: Area2D = $ScaredArea

var fear_tween: Tween

signal cell_infected

func _ready():
	scared_area.area_entered.connect(_on_scared_area_entered)
	scared_area.area_exited.connect(_on_scared_area_exited)

func apply_infection(amount: float):
	if is_fully_infected: return
	
	infection_level = clamp(infection_level + amount, 0.0, max_infection)
	var progress = infection_level / max_infection
	
	
	_shake_sprite(5)
	
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("dissolve_value", 1.0 - progress)

	if infection_level >= max_infection:
		_on_fully_infected()

func _on_fully_infected():
	is_fully_infected = true
	cell_infected.emit()
	_stop_fear_tween()
	
	var final_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	final_tween.tween_property(sprite, "scale", Vector2(1.5, 0.5), 0.1)
	final_tween.parallel().tween_property(sprite, "position:y", 10, 0.1)
	
	final_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_ELASTIC)
	final_tween.parallel().tween_property(sprite, "position:y", 0, 0.3)
	
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("dissolve_value", 0.0)

# --- OBSŁUGA STRACHU ---

func _on_scared_area_entered(_area):
	if is_fully_infected: return
	if not _area.is_in_group("Player"): 
		return
	
	_stop_fear_tween()
	
	fear_tween = create_tween().set_loops()
	# Szybkie, drobne drżenie skali (niepokój)
	fear_tween.tween_property(sprite, "scale", Vector2(0.92, 1.08), 0.05)
	fear_tween.tween_property(sprite, "scale", Vector2(1.08, 0.92), 0.05)

func _on_scared_area_exited(_area):
	if not _area.is_in_group("Player"): 
		return
	
	_stop_fear_tween()
	if not is_fully_infected:
		var back_tween = create_tween()
		back_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)

func _stop_fear_tween():
	if fear_tween and fear_tween.is_running():
		fear_tween.kill()

func _shake_sprite(intensity: float):
	var original_pos = Vector2.ZERO # Zakładając, że sprite ma lokalne (0,0)
	var shake = create_tween()
	for i in range(3):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake.tween_property(sprite, "position", offset, 0.02)
	shake.tween_property(sprite, "position", original_pos, 0.02)
