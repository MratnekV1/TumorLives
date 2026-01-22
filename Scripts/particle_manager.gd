extends Node2D

var blood_splash_scene: PackedScene = preload("res://Assets/Particles/blood_splash.tscn")
var splash_instance: CPUParticles2D
var splash_light: PointLight2D
@onready var player := $"../Player"

func _ready() -> void:
	if blood_splash_scene:
		splash_instance = blood_splash_scene.instantiate()
		add_child(splash_instance)
		splash_instance.emitting = false
		splash_instance.one_shot = true
		
		splash_light = splash_instance.get_node_or_null("LightBulb")
		if splash_light:
			splash_light.enabled = false
			splash_light.energy = 0.0
	
	if player:
		player.stealth_timeout.connect(_on_player_stealth_timeout)

func _on_player_stealth_timeout(pos: Vector2) -> void:
	if splash_instance:
		splash_instance.global_position = pos
		splash_instance.restart()
		
	if splash_light:
		_flash_blood_light()
		
func _flash_blood_light() -> void:
	splash_light.enabled = true
	splash_light.energy = .6
	
	var tween = create_tween()
	tween.tween_interval(splash_instance.lifetime * 0.7)
	tween.tween_property(splash_light, "energy", 0.0, splash_instance.lifetime * 0.5)
	tween.tween_callback(func(): splash_light.enabled = false)
