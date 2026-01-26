extends Control

@export var hover_scale := Vector2(1.1, 1.1)
@export var normal_scale := Vector2(1.0, 1.0)
@export var transition_time := 0.2

func _ready():
	for button in find_children("*", "Button"):
		button.pivot_offset = button.size / 2
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))

func _on_button_mouse_entered(btn: Button):
	var tween = create_tween()
	tween.tween_property(btn, "scale", hover_scale, transition_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_button_mouse_exited(btn: Button):
	var tween = create_tween()
	tween.tween_property(btn, "scale", normal_scale, transition_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_start_pressed():
	var tween = create_tween()
	tween.tween_property($CenterContainer/VBoxContainer/StartButton/Start, "scale", Vector2(0.8, 0.8), 0.1)
	tween.tween_callback(func(): 
		SceneManager.load_scene("res://Scenes/main.tscn")
	).set_delay(0.1)

func _on_exit_pressed():
	get_tree().quit()
