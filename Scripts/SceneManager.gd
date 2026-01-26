extends Node

var target_scene_path: String
var progress = []

func load_scene(path: String):
	target_scene_path = path
	get_tree().change_scene_to_file("res://Scenes/loading.tscn")
