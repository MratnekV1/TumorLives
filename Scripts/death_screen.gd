extends Control

@onready var overlay: ColorRect = $DeathOverlay
@onready var label: Label = $CenterContainer/Label

var can_skip: bool = false

func _ready() -> void:
	overlay.modulate.a = 1.0
	label.modulate.a = 0.0
	label.scale = Vector2(0.5, 0.5)
	
	label.pivot_offset = label.size / 2 
	
	_start_juicy_sequence()

func _start_juicy_sequence() -> void:
	var tween = create_tween().set_parallel(true)
	
	tween.tween_property(label, "modulate:a", 1.0, 1.0).set_delay(0.5)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 1.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(0.5)
	
	tween.chain().tween_callback(func(): can_skip = true)
	
	get_tree().create_timer(10.0).timeout.connect(_go_to_menu)

func _input(event: InputEvent) -> void:
	if can_skip and (event is InputEventKey or event is InputEventMouseButton):
		if event.is_pressed():
			_go_to_menu()

func _go_to_menu() -> void:
	if not can_skip: return 
	can_skip = false
	set_process(false)
	
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _process(_delta: float) -> void:
	if label.modulate.a > 0.9:
		var pulse = 1.0 + (sin(Time.get_ticks_msec() * 0.002) * 0.03)
		label.scale = Vector2(pulse, pulse)
